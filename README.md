# SmartHandToolsBLEAppProject
A BLE companion app to the ML tool created by the Smart Hand Tools Tech team under the Good Systems initiative at UT Austin. The project is comprised of am Arduino Nano BLE Sense microntroller that is mounted on a rotary hand tool which reads in data from onboard sensors. It then runs this data though a TensorFlow Lite Micro model that uses it to classify what task the user is performing at any given time. This classification, as well as the raw sensor values are then sent via Bluetooth LE protocol to an IOS companion app that graphically displays and logs values. 


## Reading in sensor data and performing inference
Using the onboard sensors, the arduino microcontroller collects the acceleration and gyration in all 3 axis and processes that data into a smaller 8 bit size. Additionally, the arduino is able to compute tilt angles, using sensor fusion, where we can determine, live, the pitch and yaw of the smart tools we were working with- a welding torch and a dremel. The code then packages all this relevant data together and broadcasts it to the client connection through the app at a frequency of 10Hz, there the data is stored and those statistics are displayed for the user to use. Additionally, at 2 second intervals, the trained model deployed on the arduino microcontroller will make an inference about the classification of task being conducted and send it to the application. 

## Receiving data live via Bluetooth
The classifications resullt as well as the raw sensor values are communicated to the IOS companion app. Rather than interfacing with the CoreBluetooth library, we chose to use the bluejay (https://github.com/steamclock/bluejay) library to abstract some of the lower-level function. Additionally, on the app side we had to use bit masking  and two's complement converstionon the app side to isolate and pull out the specific bits we need and convert to readable decimal values.

## Displaying data live via Charts API
This data is then stored internally and displayed graphically via the IOS charts API (https://github.com/danielgindi/Charts). There is an option to then save this data to a timestamped via UserDefaults which can later be viewed at any time.

## Link to the demo
https://drive.google.com/file/d/1smGI8ufqjFFV-DFA-gCfXSVOqyNghzH2/view?usp=sharing
