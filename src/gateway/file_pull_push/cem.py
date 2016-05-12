#!/usr/bin/python

import subprocess
from subprocess import Popen
import os.path
import sys
import re
import time
import signal
from datetime import datetime
from Queue import Queue, Empty
from threading import Lock, Thread, Event
import json
import logging
import logging.handlers
import ConfigParser
from optparse import OptionParser  # Replaced by argparse in py2.7


DEFAULT_CONF_FILE = "./cem.conf"

# Refresh kinit after this time has expired. Seconds
KINIT_REFRESH_INTERVAL = 3600

CEM_FILENAME_PATTERN = r'(?P<techpack>polystar)_(?P<filetype>\w*)_(?P<start>\d{10})_(?P<end>\d{10})_(?P<version>\w*)_(?P<ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\.(?P<ext>txt)\.(?P<archive>gz)_(?P<part>\d*)'

# Global flags to handle kill
ITERATION_EXIT = False
THREAD_EXIT = False

# Less than 1h is not supported and will run in ugly way
# But it shouldn't cause any data loss
MIN_POLL_FREQUENCY = 3600

THREAD_REFRESH_FREQUENCY = 0.1
SUCCESS_FILE = "_SUCCESS"

# States of items in history
COMPLETE = True
INCOMPLETE = False

# How many times to retry remote listing if it fails
LS_ATTEMPTS = 5

PIPE_NAMES = ['ssh', 'gzip', 'hdfs']

KILL_SIGNALS = [
    signal.SIGINT,
    signal.SIGTERM,
    signal.SIGHUP
]


# TODO: write more exceptions
class ProcessError(Exception):
    pass


# Wrapper
def speed_test(func):
    def wrapper(*args, **kwargs):
        t1 = time.time()
        results = func(*args, **kwargs)
        t2 = time.time()
        logging.getLogger("cem").debug("{0} took {1:.0f}s".format(func.func_name, (t2 - t1)))
        return results
    return wrapper


class Subprocess(object):
    """Provides interface for subprocess actions, such as hdfs and ssh
    Same instance should be used for all ssh actions
    """
    def __init__(self):
        self.logger = logging.getLogger("cem.proc")
        self.ssh_lock = Lock()

        self.kinit_lock = Lock()
        self.kinit_time = 0
        # Discarded output goes here
        self.devnull = open(os.devnull, 'w')
        self.ssh_master = None

        # Register kill handler
        for sig in KILL_SIGNALS:
            signal.signal(sig, self._kill_signal_handler)

    def _ssh_master(self):
        # If we have master, check his status
        self.ssh_lock.acquire()
        if self.ssh_master:
            if self.ssh_master.poll() is None:
                # All is fine, process still running
                self.ssh_lock.release()
                return

        self.logger.debug("ssh master does not exist")
        # If socket already exists
        if os.path.isfile(CEM_SOCKET):
            try:
                self.check_call(["ssh",
                                 "-O", "exit",
                                 "-S", CEM_SOCKET,
                                 "-l", CEM_USER, CEM_HOST])
            except ProcessError:
                # Failed to close master. Could mean hanging socket file or something else
                try:
                    # If socket file STILL exists, try to delete it
                    if os.path.isfile(CEM_SOCKET):
                        os.remove(CEM_SOCKET)
                except OSError:
                    # Failed to delete socket file
                    # Log very big warning why ssh multiplexing will not work
                    self.logger.exception("Failed to delete socket file")
                    self.logger.error("SSH multiplexing will not be available")

        # Create ssh master
        self.logger.info("Creating new ssh master socket")
        cmd = ["ssh",
               "-N",  # No session
               "-M",  # ControlMaster
               "-oStrictHostKeyChecking=no",  # Disable host key checking
               "-S", CEM_SOCKET,  # Socket file
               "-i", CEM_ID_FILE,
               "-l", CEM_USER, CEM_HOST]
        self.ssh_master = Popen(cmd, shell=False, stdout=self.devnull, stderr=self.devnull)
        self.ssh_lock.release()

    def stop(self):
        if self.ssh_master is not None:
            self.logger.info('Killing ssh master socket')
            self.ssh_master.terminate()
            self.ssh_master.wait()

    def _kill_signal_handler(self, signal, frame):
        global ITERATION_EXIT
        global THREAD_EXIT

        if not ITERATION_EXIT:
            self.logger.info("First kill signal. Exit will be completed after this iteration.")
            ITERATION_EXIT = True
        elif not THREAD_EXIT:
            self.logger.info("Second kill signal. Exit will be completed after threads stop.")
            THREAD_EXIT = True
        else:
            self.logger.info("Exit will be completed after threads stop.")

    def create_ssh_cmd(self, cmd):
        self._ssh_master()
        cmd_list = ["ssh",
                    "-oBatchMode=yes",  # Force no interactions
                    "-oStrictHostKeyChecking=no",  # Disable host key checking
                    "-S", CEM_SOCKET,  # Socket file
                    "-i", CEM_ID_FILE,
                    "-l", CEM_USER, CEM_HOST,
                    cmd]
        return cmd_list

    def ssh_ls(self, path):
        cmd_list = self.create_ssh_cmd("ls {0}".format(path))
        p_ssh = Popen(cmd_list, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        p_stdout, p_stderr = p_ssh.communicate()
        if p_ssh.returncode != 0:
            self.logger.debug("ssh ({0}) exit with error: {1}".format(cmd_list, p_ssh.returncode))
            raise ProcessError("SSH exit with code: {0}. Output: {1}".format(p_ssh.returncode, p_stderr))
        return p_stdout.split('\n')[:-1]  # Cut trailing newline

    def check_call(self, cmd, shell=False):
        process = Popen(cmd, shell=shell, stdout=self.devnull, stderr=self.devnull)
        process.wait()
        if process.returncode != 0:
            raise ProcessError("Cmd {0} exit with code: {1}".format(cmd, process.returncode))

    def kinit(self):
        """
        Execute kinit in shell if time interval since last iteration has been exceeded.
        Thread safe
        """
        self.kinit_lock.acquire()
        if time.time() - self.kinit_time < KINIT_REFRESH_INTERVAL:
            self.kinit_lock.release()
        else:
            self.logger.info("Refreshing kerberos ticket")
            self.check_call("kinit $USER@TCAD.TELIA.SE -k -t ~/$USER.keytab", shell=True)
            self.kinit_time = time.time()
            self.kinit_lock.release()

    def clear_hdfs_dir(self, path):
        self.kinit()
        self.check_call(["hdfs", "dfs", "-rm", "-r", "-f", "-skipTrash", path])

    def check_dir_closed(self, path):
        self.kinit()
        # Check for success file
        try:
            self.check_call(["hdfs", "dfs", "-test", "-f", os.path.join(path, SUCCESS_FILE)])
        except ProcessError:
            return False
        return True

    def safe_create_hdfs_dir(self, path):
        """Create directory in HDFS and any missing parent dirs.
        Check if directory is not closed already, then fail.
        Remove existing incomplete directory.
        """
        self.kinit()
        if not self.check_dir_closed(path):
            # Remove dir if there is previously incomplete one
            self.clear_hdfs_dir(path)
            self.check_call(["hdfs", "dfs", "-mkdir", "-p", path])
        else:
            # TODO: Should use different exception
            raise ProcessError("Attempting to overwrite closed directory {0}".format(path))

    def close_hdfs_dir(self, path):
        self.kinit()
        self.check_call(["hdfs", "dfs", "-touchz", os.path.join(path, SUCCESS_FILE)])

    def delete_hdfs_file(self, path):
        self.kinit()
        self.check_call(["hdfs", "dfs", "-rm", "-f", "-skipTrash", path])

    def pipe_file(self, source_path, dest_path):
        self.kinit()
        pull_cmd = self.create_ssh_cmd("cat {0}".format(source_path))
        push_cmd = [
            "hdfs", "dfs", "-put", "-f", "-", dest_path
        ]

        pull = Popen(pull_cmd, shell=False, stdout=subprocess.PIPE, stderr=self.devnull)
        process = Popen(["gunzip", "-c"], shell=False, stdin=pull.stdout, stdout=subprocess.PIPE, stderr=self.devnull)
        push = Popen(push_cmd, shell=False, stdin=process.stdout, stdout=self.devnull, stderr=self.devnull)

        # According to Doc stdout should be closed to pass the SIGPIPE
        # TODO: Not sure about the order of these, from testing this seems to work
        pull.stdout.close()
        process.stdout.close()

        process_list = [pull, process, push]
        for process in process_list:
            # TODO: wait() could deadlock according to Doc, maybe need to rewrite with poll() ?
            process.wait()

        for i, process in enumerate(process_list):
            if process.returncode != 0:
                raise ProcessError("Pipe process '{0}' exit with code: {1}".format(PIPE_NAMES[i], process.returncode))


class Task(object):
    def __init__(self):
        raise NotImplementedError

    def process(self):
        raise NotImplementedError


class FileTask(Task):
    def __init__(self, func, src_name, dst_name, src, dst, stream, day):
        self.status = INCOMPLETE
        self.func = func
        self.name = dst_name

        self.src_name = src_name
        self.dst_name = dst_name
        self.src = src
        self.dst = dst
        self.stream = stream
        self.day = day

    def process(self):
        self.func(self.src, self.dst)


class FileCleanup(Task):
    def __init__(self, func, path):
        self.status = INCOMPLETE
        self.func = func
        self.name = path

        self.path = path

    def process(self):
        self.func(self.path)


class DirectoryTask(Task):
    def __init__(self, func, path):
        self.status = INCOMPLETE
        self.func = func
        self.name = path

        self.path = path

    def process(self):
        self.func(self.path)


class Worker(Thread):
    def __init__(self, task_queue, completed_list, exit_event, *args, **kwargs):
        Thread.__init__(self, *args, **kwargs)
        self.logger = logging.getLogger("cem.worker." + self.name)
        self.queue = task_queue
        self.done = completed_list
        self.exit_event = exit_event

    def run(self):
        # Loop until out of tasks or exit requested
        empty = False
        while not empty and not self.exit_event.is_set():
            try:
                task = self.queue.get(block=False)
                self.process_task(task)
                self.queue.task_done()
            except Empty:
                empty = True

    def process_task(self, task):
        try:
            t1 = time.time()
            task.process()
            t2 = time.time()
            self.logger.debug("Task {1} completed {0} in {2:.2f}s".format(task.name, task.func.__name__, (t2 - t1)))
        except ProcessError as e:
            task.status = INCOMPLETE
            self.logger.debug("Task {1} failed {0}: {2}".format(task.name, task.func.__name__, str(e)))
        except Exception as e:
            # Uknown errors from task is logged here, and ignored
            task.status = INCOMPLETE
            self.logger.exception("Task {1} with {0} encountered error".format(task.name, task.func.__name__))
        else:
            # If no errors, mark task as completed
            task.status = COMPLETE
        self.done.append(task)


class Poll(object):
    """A single poll iteration
    """

    def __init__(self, proc, history):
        self.logger = logging.getLogger("cem.poll")
        self.proc = proc
        self.history_src = history['src']
        # TODO: current dst history is not used
        self.history_dst = history['dst']

    def poll(self):
        self.logger.info("Polling CEM for new files")

        # Save the time of poll
        self.poll_time = datetime.utcnow()
        # Read CEM fs tree
        ls_success = False
        attempt = 0
        while not ls_success:
            try:
                cem_state = self._get_cem_tree()
            except ProcessError as e:
                logger.debug("Failed to list remote fs: {0}".format(str(e)))
                if not attempt < LS_ATTEMPTS:
                    logger.error("Failed to list remote fs with {0} attempts".format(LS_ATTEMPTS))
                    raise
                attempt += 1
            else:
                ls_success = True

        if args.debug:
            # Write listed tree to file for debug
            with open("./cem_poll_{0}".format(datetime.now()), "w") as f:
                f.write(json.dumps(cem_state, sort_keys=True, indent=4))

        self.logger.info("Clearing history")
        # First remove files from history that are no longer in CEM (free up memory)
        self.clear_lost_files(cem_state)
        # Then add new files to history, to be fetched
        self.register_new_files(cem_state)

        self.logger.info("Searching for new files")
        self.incomplete_files = self._find_incomplete_files()

        self.logger.info("Preparing HDFS directory structure")
        self.create_new_directories()
        self.logger.info("Fetching new files to HDFS")
        self.fetch_new_files()
        self.cleanup_failed_files()

        # TODO: Would be nice feature to close only when hour has switched,
        # then we can safe work with iteration less than 1h
        if CLOSE_HDFS_DIRS:
            self.logger.info("Closing HDFS directories")
            self.close_new_directories()
        else:
            self.logger.info("Skipping close HDFS directories because of configured settings")

    @speed_test
    def _get_cem_tree(self, file_value=COMPLETE):
        tree = {}
        for stream in CEM_STREAMS:
            days_in_dir = self.proc.ssh_ls(os.path.join(CEM_BASE_DIR, stream))
            days = {}
            for day in days_in_dir:
                files_in_day = self.proc.ssh_ls(os.path.join(CEM_BASE_DIR, stream, day))
                days[day] = {}
                for f in files_in_day:
                    # Add each file
                    days[day][f] = file_value
            tree[stream] = days
        return tree

    def clear_lost_files(self, cem):
        history = self.history_src
        for stream in CEM_STREAMS:
            # We can't simply iterate over history if we are deleting items from it
            # keys() method works though
            for day in history[stream].keys():
                if day not in cem[stream]:
                    # CEM has lost this day
                    # Report any unfinished files
                    # And clear from history
                    for file_name in history[stream][day].keys():
                        if history[stream][day][file_name] == INCOMPLETE:
                            self.logger.warning("File {0}/{1}/{2} has been lost, it was not completed and day {1} is no longer available on CEM".format(stream, day, file_name))
                    self.logger.debug("Clearing day {0}/{1} from history as it's no longer available on CEM".format(stream, day))
                    del(history[stream][day])
                else:
                    # TODO: Technically we should not need to check by files as CEM clears whole directory
                    # (and we would check then) but I still do it anyway
                    for file_name in history[stream][day].keys():
                        if file_name not in cem[stream][day]:
                            if history[stream][day][file_name] == INCOMPLETE:
                                self.logger.warning("File {0} has been lost, it was not completed and file is no longer available on CEM".format(file_name))
                            else:
                                self.logger.debug("File {0}/{1}/{2} has dissapeared from CEM, but was completed.".format(stream, day, file_name))

    def register_new_files(self, cem):
        history = self.history_src
        for stream in CEM_STREAMS:
            for day in cem[stream]:
                if day not in history[stream]:
                    # New day has arived, add to history
                    history[stream][day] = {}
                for file_name, status in cem[stream][day].iteritems():
                    if file_name not in history[stream][day]:
                        # If file not yet in history, add as incomplete
                        history[stream][day][file_name] = INCOMPLETE

    @speed_test
    def _find_incomplete_files(self, ignore_streams=[]):
        history = self.history_src
        incomplete_files = {}
        for stream in CEM_STREAMS:
            if stream in ignore_streams:
                # Stream to be skipped
                continue

            days = {}
            for day in history[stream]:
                files = []
                for file_name, status in history[stream][day].iteritems():
                    if status == INCOMPLETE:
                        #self.logger.debug("File {0} status {1}".format(file_name, status))
                        files.append(file_name)
                if files:
                    days[day] = files
            if days:
                incomplete_files[stream] = days
        return incomplete_files

    def create_new_directories(self):
        # Find which directories will be needed for new files
        tasks = self.create_directory_tasks(self.incomplete_files)
        self.logger.info("{0} new directories to create".format(tasks.qsize()))
        # Create them
        completed_tasks = self.consume_tasks(tasks, worker_count=LOCAL_WORKER_LIMIT)

        self.completed_directories = []
        # Check task status
        for directory in completed_tasks:
            if directory.status == COMPLETE:
                self.logger.debug("Created {0}".format(directory.name))
                self.completed_directories.append(directory.path)
            else:
                self.logger.error("Failed to create directory {0}".format(directory.name))

    def create_directory_tasks(self, incomplete_files):
        directory_tasks = Queue()
        for stream in incomplete_files:
                dst_dir = os.path.join(HDFS_BASE_DIR, stream, self._time_path())
                task = DirectoryTask(self.proc.safe_create_hdfs_dir, path=dst_dir)
                directory_tasks.put(task)
                #self.logger.debug("new directory task {0}".format(dst_dir))
        return directory_tasks

    def fetch_new_files(self):
        # Create new tasks
        tasks = self.create_file_tasks(self.incomplete_files)
        self.logger.info("{0} new files to fetch".format(tasks.qsize()))
        # Fetch the files
        completed_tasks = self.consume_tasks(tasks, worker_count=REMOTE_WORKER_LIMIT)

        self.cleanup_tasks = Queue()
        # Check status and update history with completed files
        for file_task in completed_tasks:
            if file_task.status == COMPLETE:
                #self.logger.debug("Successfully fetched file {0}".format(file_task.name))
                self.history_src[file_task.stream][file_task.day][file_task.src_name] = COMPLETE
            else:
                self.logger.debug("Failed to fetch file {0}".format(file_task.name))
                cleanup_task = FileCleanup(self.proc.delete_hdfs_file, file_task.dst)
                self.cleanup_tasks.put(cleanup_task)

    def create_file_tasks(self, incomplete_files):
        file_tasks = Queue()
        for stream in incomplete_files:
            for day in incomplete_files[stream]:
                for new_file in incomplete_files[stream][day]:
                    source_path = os.path.join(CEM_BASE_DIR, stream, day, new_file)
                    file_parts = self.split_cem_filename(new_file)
                    dst_file_name = "{techpack}_{filetype}_{start}_{end}_{version}_{ip}.{ext}_{part}".format(**file_parts)
                    dst_dir = os.path.join(HDFS_BASE_DIR, stream, self._time_path())
                    # Verify that this directory was successfully created
                    if dst_dir not in self.completed_directories:
                        self.logger.debug("skipping file {1} because destination directory {0} wasn't created".format(dst_dir, source_path))
                        continue
                    dst_path = os.path.join(dst_dir, dst_file_name)
                    task = FileTask(self.proc.pipe_file, src_name=new_file,
                                    dst_name=dst_file_name,
                                    src=source_path, dst=dst_path,
                                    stream=stream, day=day)
                    file_tasks.put(task)
                    #self.logger.debug("new file task {0}".format(new_file))
        return file_tasks

    def cleanup_failed_files(self):
        self.logger.info("{0} failed files to clean up".format(self.cleanup_tasks.qsize()))
        # Fetch the files
        completed_tasks = self.consume_tasks(self.cleanup_tasks, worker_count=LOCAL_WORKER_LIMIT)
        # TODO: check completed cleanups. For now its rm -f, so erros will be something serious

    def close_new_directories(self):
        # Find which directories will be needed for new files
        tasks = self.create_close_tasks(self.incomplete_files)
        self.logger.info("{0} new directories to close".format(tasks.qsize()))
        # Create them
        completed_tasks = self.consume_tasks(tasks, worker_count=LOCAL_WORKER_LIMIT)

        # Check task status
        for directory in completed_tasks:
            if directory.status == COMPLETE:
                self.logger.debug("Closed {0}".format(directory.name))
            else:
                self.logger.error("Failed to close directory {0}".format(directory.name))

    def create_close_tasks(self, incomplete_files):
        directory_tasks = Queue()
        for stream in incomplete_files:
                dst_dir = os.path.join(HDFS_BASE_DIR, stream, self._time_path())
                # Verify that this directory was successfully created
                if dst_dir not in self.completed_directories:
                    self.logger.debug("skipping close task {0} because directory wasn't created".format(dst_dir))
                    continue
                task = DirectoryTask(self.proc.close_hdfs_dir, path=dst_dir)
                directory_tasks.put(task)
                self.logger.debug("new close task {0}".format(dst_dir))
        return directory_tasks

    def _time_path(self):
        """
        Create Raw structured directory, from current time
        <Y>/<M>/<D>/<H>
        Also add zero padding up to 2 digits
        """
        return os.path.join(str(self.poll_time.year),
                            "{0:02d}".format(self.poll_time.month),
                            "{0:02d}".format(self.poll_time.day),
                            "{0:02d}".format(self.poll_time.hour))

    def consume_tasks(self, tasks, worker_count):
        completed_tasks = []
        exit_event = Event()
        # Create workers
        workers = []
        for i in xrange(worker_count):
            workers.append(Worker(tasks, completed_tasks, exit_event, name=i + 1))

        # Start all workers
        for worker in workers:
            worker.start()

        # Wait until all workers are done
        done = False
        while not done:
            time.sleep(THREAD_REFRESH_FREQUENCY)

            # Handling if we get kill signal
            if THREAD_EXIT:
                exit_event.set()
                self.logger.info("Waiting for all threads to exit")
                for worker in workers:
                    worker.join()
                self.proc.stop()
                self.logger.info("Exit")
                sys.exit(3)

            for worker in workers:
                if worker.is_alive():
                    break
            else:
                done = True

        return completed_tasks

    def timedelta_in_seconds(self, timedelta):
        """Available native in timedeltas since python 2.7
        """
        return (
            timedelta.microseconds + 0.0 +
            (timedelta.seconds + timedelta.days * 24 * 3600) * 10 ** 6) / 10 ** 6

    def split_cem_filename(self, name):
        match = re.search(CEM_FILENAME_PATTERN, name)
        if not match:
            raise RuntimeError("name [{0}] doesn't match CEM filename pattern".format(name))
        return match.groupdict()


class Poller(object):
    """Main poll class which loads initial/previous history
    and then runs forever building and executing each iteration
    """
    def __init__(self, poll_time, history_file):
        self.logger = logging.getLogger("cem.poller")

        self.poll_time = poll_time
        self.history_file = history_file

        # TODO: Give config args
        self.proc = Subprocess()
        # Load history

        try:
            self.history = self.get_history()
        except Exception:
            logger.exception("Unable to get history")
            self.proc.stop()
            logger.error("Exit")
            sys.exit(4)

        if CLEAR_HDFS:
            # Clear previous data from hdfs
            self.logger.info("Deleting previous data from HDFS {0}".format(HDFS_BASE_DIR))
            self.proc.clear_hdfs_dir(HDFS_BASE_DIR)

    def get_history(self):
        """Returns history object (complicated dict structure)
        Either loads it from history file if possible, or builds a new one.
        """
        history = None

        # Read last history from history file
        if os.path.isfile(self.history_file):
            self.logger.info("Loading previous history from file")
            try:
                with open(self.history_file, 'r') as f:
                    history_json = f.read()
                    try:
                        history = json.loads(history_json)
                    except Exception:
                        self.logger.error("History from file {0} was corrupted".format(self.history_file))
                        raise
            except IOError:
                self.logger.error("Unable to read history file {0}".format(self.history_file))
                raise

        if history:
            if args.debug:
                # Write listed tree to file for debug
                with open("./cem_poll_initial_{0}".format(datetime.now()), "w") as f:
                    f.write(json.dumps(history['src'], sort_keys=True, indent=4))

        if not history:
            try:
                self.logger.info("Building new initial history")
                t1 = time.time()

                initial_history_success = False
                attempt = 0
                while not initial_history_success:
                    try:
                        source_history = self._create_initial_source_history()
                    except ProcessError as e:
                        logger.debug("Failed to list remote fs: {0}".format(str(e)))
                        if not attempt < LS_ATTEMPTS:
                            logger.error("Failed to list remote fs with with {0} attempts".format(LS_ATTEMPTS))
                            raise
                        attempt += 1
                    else:
                        initial_history_success = True

                if args.debug:
                    # Write listed tree to file for debug
                    with open("./cem_poll_initial_{0}".format(datetime.now()), "w") as f:
                        f.write(json.dumps(source_history, sort_keys=True, indent=4))

                # Mark current status of HDFS as empty
                # TODO: destination history is currently unused
                destination_history = {}
                history = {"src": source_history, "dst": destination_history, "timestamp": None}

                t2 = time.time()
                history_time = t2 - t1
                if(history_time < self.poll_time):
                    self.logger.info("Waiting {0:.0f}s for initial files".format(self.poll_time - history_time))
                    time.sleep(self.poll_time - history_time)

            except ProcessError:
                logger.error("Failed to build initial history")
                raise
        return history

    @speed_test
    def _create_initial_source_history(self):
        history = {}
        for stream in CEM_STREAMS:
            days_in_dir = self.proc.ssh_ls(os.path.join(CEM_BASE_DIR, stream))
            days = {}
            for day in days_in_dir:
                files_in_day = self.proc.ssh_ls(os.path.join(CEM_BASE_DIR, stream, day))
                days[day] = {}
                for f in files_in_day:
                    # Add each file, mark as completed
                    days[day][f] = COMPLETE
            history[stream] = days
        return history

    def loop(self):
        delay = 0
        iteration = 0
        while True:
            # First check if we have been killed before this iteration
            if ITERATION_EXIT:
                self.logger.info("Exiting iteration because of kill signal")
                self.proc.stop()
                break

            self.logger.info("Starting iteration {0}".format(iteration))

            t1 = time.time()
            # Create and run one Poll
            try:
                p = Poll(self.proc, self.history)
                p.poll()
            except Exception as e:
                logger.error("Exception encountered during iteration: {0} - {1}".format(type(e), str(e)))
            t2 = time.time()

            current_exec_time = t2 - t1
            #Display as percent
            self.logger.info("Completed in {0:.2%} of available time".format(current_exec_time / self.poll_time))

            # Write latest history in file for error recovery
            self.logger.info("Writing history to file")
            self.store_history()

            if ITERATION_LIMIT and iteration + 1 == ITERATION_LIMIT:
                self.logger.info("Polling completed after {0} iterations".format(ITERATION_LIMIT))
                self.proc.stop()
                break

            if ITERATION_EXIT:
                self.logger.info("Exiting iteration because of kill signal")
                self.proc.stop()
                break

            # If we finish fast enough we can sleep before next iteration
            if current_exec_time < self.poll_time:
                delay = 0
                until_next_iteration = self.poll_time - current_exec_time
                self.logger.info("Sleeping {0:.0f}s until next iteration".format(until_next_iteration))
                time.sleep(until_next_iteration)
            else:
                delay += current_exec_time - self.poll_time
                self.logger.info("Poll iteration exceeded iteration time by {0:.2%}".format(current_exec_time / self.poll_time))
                if delay > CLOSE_WINDOW:
                    # TODO: Warn that we have reached unrecoverable delay
                    self.logger.warning("Poll delay [{0}] has exceeded configured recoverable window [{1}]".format(delay, CLOSE_WINDOW))

            iteration += 1

    @speed_test
    def store_history(self):
        # Insert current time in history
        self.history["timestamp"] = time.time()
        history_json = json.dumps(self.history)
        with open(self.history_file, 'w') as f:
            f.write(history_json)


def get_cli_args():
    parser = OptionParser()
    parser.add_option("-c", "--conf-file", dest="conf_file",
                      help="Path to config file", default=DEFAULT_CONF_FILE)
    parser.add_option("-N", "--no-close", dest="close_hdfs", action="store_false",
                      default=True, help="Don't close HDFS directories")
    parser.add_option("-d", "--debug",
                      action="store_true", dest="debug", default=False,
                      help="Enable debug")
    parser.add_option("-i", "--iterations", type="int", default=0,
                      help="Run specified count of iterations")

    (options, args) = parser.parse_args()
    return options


def get_config(conf_file):
    # Read config file
    config = ConfigParser.SafeConfigParser()
    if config.read(conf_file):
        return config
    else:
        return None


def setup_logging(log_file, log_retention_days, debug_file, debug_retention_days):
    # Create main logger
    logger = logging.getLogger("cem")
    logger.setLevel(logging.DEBUG)

    #console = logging.StreamHandler()
    #console.setLevel(logging.DEBUG)

    logfile = logging.handlers.TimedRotatingFileHandler(log_file, when="midnight", backupCount=log_retention_days)
    logfile.setLevel(logging.INFO)

    debugfile = logging.handlers.TimedRotatingFileHandler(debug_file, when="midnight", backupCount=debug_retention_days)
    debugfile.setLevel(logging.DEBUG)

    # For some reason timezone (%z) is not available/correct. This might be something old. %Z is possible
    formatter = logging.Formatter("%(asctime)s %(name)-13s %(levelname)-8s %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    logfile.setFormatter(formatter)
    debugfile.setFormatter(formatter)

    logger.addHandler(logfile)
    logger.addHandler(debugfile)

    return logger


def get_stream_list(list_file):
    with open(list_file, "r") as f:
        # TODO: Some validation?
        return [line.rstrip('\n') for line in f]


if __name__ == "__main__":
    # cd to script's location, for relative paths
    # relative current dir is empty string and fails, so check for that
    if os.path.dirname(sys.argv[0]):
        os.chdir(os.path.dirname(sys.argv[0]))
    # Read cli args
    args = get_cli_args()

    CLOSE_HDFS_DIRS = args.close_hdfs
    ITERATION_LIMIT = args.iterations

    print("Reading config file {0}".format(args.conf_file))
    conf = get_config(os.path.expanduser(args.conf_file))
    if not conf:
        raise RuntimeError("Failed to load config file {0}".format(args.conf_file))

    log_file = os.path.expanduser(conf.get("logging", "log_file"))
    log_retention_days = conf.getint("logging", "log_retention_days")
    debug_file = os.path.expanduser(conf.get("logging", "debug_file"))
    debug_retention_days = conf.getint("logging", "debug_retention_days")
    print("Starting logger")
    logger = setup_logging(log_file, log_retention_days, debug_file, debug_retention_days)

    # TODO: Rename all from constants to variables

    HISTORY_FILE = os.path.expanduser(conf.get("main", "history_file"))
    LOCAL_WORKER_LIMIT = conf.getint("main", "local_workers")
    REMOTE_WORKER_LIMIT = conf.getint("main", "remote_workers")

    LOOP_TIME = conf.getint("main", "poll_frequency")
    if LOOP_TIME < MIN_POLL_FREQUENCY:
        raise RuntimeError("Configured 'poll_frequency' [{0}] is less than minimal [{0}]\n".format(LOOP_TIME, MIN_POLL_FREQUENCY))

    # TODO: This is now only used for warning message. Name should be changed.
    CLOSE_WINDOW = conf.getint("main", "close_window")

    CEM_BASE_DIR = conf.get("main", "cem_base_dir")
    HDFS_BASE_DIR = conf.get("main", "hdfs_base_dir")

    CLEAR_HDFS = conf.getboolean("main", "clear_hdfs")

    # Load list of CEM streams from file
    CEM_STREAMS = get_stream_list(os.path.expanduser(conf.get("main", "stream_list_file")))

    CEM_HOST = conf.get("ssh", "cem_host")
    CEM_USER = conf.get("ssh", "cem_user")
    CEM_SOCKET = os.path.expanduser(conf.get("ssh", "cem_socket"))
    CEM_ID_FILE = os.path.expanduser(conf.get("ssh", "cem_id_file"))

    logger.info("Starting")
    p = Poller(LOOP_TIME, HISTORY_FILE)
    # Run
    p.loop()
    logger.info("Exit")
