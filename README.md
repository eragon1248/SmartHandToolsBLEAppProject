# SmartHandToolsBLEAppProject
A BLE companion app to the ML tool created by the Smart Hand Tools Tech team under the Good Systems initiative at UT Austin. The project is comprised of am Arduino Nano BLE Sense microntroller that is mounted on a rotary hand tool which reads in data from onboard sensors. It then runs this data though a TensorFlow Lite Micro model that uses it to classify what task the user is performing at any given time. This classification, as well as the raw sensor values are then sent via Bluetooth LE protocol to an IOS companion app that graphically displays and logs values. 


**Reading in sensor data and performing inference**

**Receiving data live via Bluetooth**

**Displaying data live via Charts API**

**Saving data to be viewed later**

