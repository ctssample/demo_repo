#!/usr/bin/env bash
# Bash script to run through folders and execute action for older than what is specified in retention.properties

set -o errexit
set -o nounset

# Function to handle files that are over the retention time
function remove_old {
	hadoop fs -rm -r $1
	echo "$(date +%Y-%m-%d_%H:%M) Removed directory $1"
}

# Main function
if [[ "$#" -ne "2" || "$2" -le 0 ]]; then
	echo "Arguments: 1) Directory with a date sub-structure, 2) Retention time in days as an integer"
	exit
fi

directory=$1
retention_time=$2
current_year=$(date +%Y)
current_month=$(date +%m)
current_day=$(date +%d)

# Oldest date for which the data is still retained
oldest_retained=$(date --date="-$retention_time days") 
oldest_retained_year=$(date --date="$oldest_retained" +%Y)
oldest_retained_month=$(date --date="$oldest_retained" +%m)
oldest_retained_day=$(date --date="$oldest_retained" +%d)

echo "------------------ START ------------------"
echo "$(date) Start"
echo "Running retention handling in $directory"
echo "Current date is: ${current_year}/${current_month}/${current_day}"
echo "Oldest to be retained will be: ${oldest_retained_year}/${oldest_retained_month}/${oldest_retained_day}"

# Go through directories starting from year level
echo "Starting processing year level"
years=`hadoop fs -ls $directory | grep $directory | awk -F'/' '{print $NF}'` 
echo "$years"
for year in $years 
do
	if [ "$year" -lt "$oldest_retained_year" ]; then
		remove_old $directory/$year
	elif  [ "$year" -eq "$oldest_retained_year" ]; then
		echo "Starting processing month level"
		months=`hadoop fs -ls $directory/$year/ | grep $directory | awk -F'/' '{print $NF}'`
		for month in $months
		do
			if [ "$month" -lt "$oldest_retained_month" ]; then
				remove_old $directory/$year/$month
			elif [ "$month" -eq "$oldest_retained_month" ]; then
				echo "Starting processing day level"
				days=`hadoop fs -ls $directory/$year/$month/ | grep $directory | awk -F'/' '{print $NF}'`
				for day in $days
				do
					if [ "$day" -lt "$oldest_retained_day" ]; then
						remove_old $directory/$year/$month/$day
					else
						break
					fi
				done
			else
				break
			fi
		done
	else
		break
	fi
done
echo "$(date) End"
echo "------------------ END ------------------"



