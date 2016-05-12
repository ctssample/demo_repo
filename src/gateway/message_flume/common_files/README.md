The file contains information about flume/cusin deployment process.

The process consists of the following steps:
1. Prerequisite: <release> of code application sholuld be deployed and <environment> set up should be done according to deployment instruction.
2. Copy file for authentification in Tibco EMS into /opt/cdl/keys/<environment>/swe/jms_utf8.txt on Edge Host.
3. To check that flume is not warking already, use the following command: screen -ls
4. To create new screen for flume, use the following command: screen -S <name> (example: flume)
5. To run the following command from Edge Host command line: flume-ng agent -c /opt/cdl/<environment>/swe/message_flume/<release>-instance-1/ -f /opt/cdl/<environment>/swe/message_flume/<release>-instance-1/flume.conf -n <agent name from flume.conf> --plugins-path /opt/cdl/<environment>/swe/message_flume/<release>-instance-1/plugins.d/
6. After that the created screen can be closed.
7. Logs can be seen on Edge host in: /var/log/flume-ng/flume.log
8. To kill flume job, use the following command: screen -X -S <name> (example: flume) kill
9. Detailed information about Cusin data source described in "Design document Cusin" in http://workroom.teliasonera.net/sites/datalake/
