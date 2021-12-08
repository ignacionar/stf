#!/bin/bash

echo "[$(date +'%d/%m/%Y %H:%M:%S')] populating device info"
PLATFORM_VERSION=$(ios info --udid=$DEVICE_UDID | jq -r ".ProductVersion")
  # TODO: detect tablet and TV for iOS, also review `ios info` output data like below
    #"DeviceClass":"iPhone",
    #"ProductName":"iPhone OS",
    #"ProductType":"iPhone10,5",
    #"ProductVersion":"14.7.1",
    #"SerialNumber":"C38V961BJCM2",
    #"TimeZone":"Europe/Minsk",
    #"TimeZoneOffsetFromUTC":10800,


echo "[$(date +'%d/%m/%Y %H:%M:%S')] Installing WDA application on device"
ios install --path=/opt/WebDriverAgent.ipa --udid=$DEVICE_UDID

echo "[$(date +'%d/%m/%Y %H:%M:%S')] Activating default com.apple.springboard during WDA startup"
ios launch com.apple.springboard

echo "[$(date +'%d/%m/%Y %H:%M:%S')] Starting WebDriverAgent application on port $WDA_PORT"
ios runwda --bundleid=$WDA_BUNDLEID --testrunnerbundleid=$WDA_BUNDLEID --xctestconfig=WebDriverAgentRunner.xctest --env USE_PORT=$WDA_PORT --env MJPEG_SERVER_PORT=$MJPEG_PORT --env UITEST_DISABLE_ANIMATIONS=YES --udid $DEVICE_UDID > ${WDA_LOG_FILE} 2>&1 &

#Start the WDA service on the device using the WDA bundleId
ip=""
#Parse the device IP address from the WebDriverAgent logs using the ServerURL
#We are trying several times because it takes a few seconds to start the WDA but we want to avoid hardcoding specific seconds wait

#TODO: try to parse and read WDA_PORT and MJPEG_PORT as well
echo detecting WDA_HOST ip address...
for ((i=1; i<=$WDA_WAIT_TIMEOUT; i++))
do
 if [ -z "$ip" ]
  then
   #{"level":"info","msg":"2021-12-08 19:26:18.502735+0300 WebDriverAgentRunner-Runner[8680:8374823] ServerURLHere-\u003ehttp://192.168.88.155:8100\u003c-ServerURLHere\n","time":"2021-12-08T16:26:18Z"}
   ip=`grep "ServerURLHere-" ${WDA_LOG_FILE} | cut -d ':' -f 7`
   WDA_PORT=`grep "ServerURLHere-" ${WDA_LOG_FILE} | cut -d ':' -f 8 | cut -d '\' -f 1`
   echo "attempt $i"
   sleep 1
  else
   break
 fi
done

if [[ -z $ip ]]; then
  echo "ERROR! Unable to parse WDA_HOST ip from log file!"
  cat $WDA_LOG_FILE
  # Below exit completely destroy appium container as there is no sense to continue with undefined WDA_HOST ip!
  exit -1
fi

export WDA_HOST="${ip//\//}"
echo "Detected WDA_HOST ip: ${WDA_HOST}"
echo "WDA_PORT=${WDA_PORT}"


echo "WDA_HOST=${WDA_HOST}" > ${WDA_ENV}
echo "WDA_PORT=${WDA_PORT}" >> ${WDA_ENV}
echo "MJPEG_PORT=${MJPEG_PORT}" >> ${WDA_ENV}
echo "PLATFORM_VERSION=${PLATFORM_VERSION}" >> ${WDA_ENV}