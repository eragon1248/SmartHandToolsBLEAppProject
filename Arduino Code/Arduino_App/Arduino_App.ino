#include <Smart_Tool_Classification_Edge_Impulse_Demo_1_inferencing.h>
#include <ArduinoBLE.h>
#include <Arduino_LSM9DS1.h>

// Declare Service UUID
const char* deviceServiceUuid = "9afbe4be-5be4-4ae8-a173-9aba49ec38fd";

// Initializing Variables
signed char accelX = 1;
signed char accelY = 1;
signed char accelZ = 1;
signed char gyroX = 1;
signed char gyroY = 1;
signed char gyroZ = 1;
float x, y, z;
float x2, y2, z2;
float magx, magy, magz;
int arrayCount = 0;

// Initializing Variables for Pitch and Roll Angles
// Measured inclination based on accelerometer X axis
float thetaM;
// Measured inclination based on accelerometer y axis
float phiM;
// Measured inclination based on gyroscope x axis
float thetaG = 0;
// Measured inclination based on gyroscope y axis
float phiG = 0;

// Final tilt angle values for roll and pitch, respectively
float theta;
signed char roll = 1;
float phi;
signed char pitch = 1;
float psi;
signed char yaw = 1;

// Time Management Variables
float dt;
unsigned long millisOld;
int sensorUpdateInterval = 50;
int inferenceUpdateInterval = 2000;
static unsigned long startTime = 0;

// Trained Model Variables
#define CONVERT_G_TO_MS2    9.80665f
#define MAX_ACCEPTED_RANGE  2.0f
static bool debug_nn = false; // Set this to true to see e.g. features generated from the raw signal
float ei_get_sign(float number) {
  return (number >= 0.0) ? 1.0 : -1.0;
}

/*
  If needed to place identifiers with output values
  // print the UUID of the characteristic
  Serial.print("\tCharacteristic ");
  Serial.println(characteristic.uuid());
  // print the byte size of charecteristic
  Serial.print("Byte size: ");
  Serial.println(sizeof(characteristic));
*/

// Declare Service
BLEService agmService(deviceServiceUuid);

// Output Array
BLECharacteristic customArrayChar("0327aa75-d27e-40b8-bfb5-b333c2a37dc6", BLERead | BLENotify | BLEBroadcast, 128, true);
BLEUnsignedIntCharacteristic customXChar("044DDFD6-FBA4-4D94-B9E2-FB2AE619DFC7", BLERead | BLENotify | BLEBroadcast);

void setup() {
  IMU.begin();
  Serial.begin(9600);

  // Caibration of Magnetometer - Replaceable
  IMU.setMagnetFS(0);
  IMU.setMagnetODR(8);
  IMU.setMagnetOffset(19.246216, 18.193359, 3.260498);
  IMU.setMagnetSlope (1.859274, 1.662833, 1.755710);
  // End of Calibration Values
  IMU.magnetUnit = MICROTESLA;

  while (!Serial);

  pinMode(LED_BUILTIN, OUTPUT);

  if (!BLE.begin()) {
    Serial.println("BLE failed to Initiate");
    while (1);
  }

  // Set advertised local name and service UUID
  BLE.setLocalName("Sensor Data");
  BLE.setAdvertisedService(agmService);
  // Add characteristic(s) to the service
  agmService.addCharacteristic(customArrayChar);
  agmService.addCharacteristic(customXChar);
  // Add Service
  BLE.addService(agmService);
  // Start Advertising
  BLE.advertise();
  if (EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME != 3) {
    ei_printf("ERR: EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME should be equal to 3 (the 3 sensor axes)\n");
    return;
  }
  Serial.println("Bluetooth device is now active, waiting for connections...");
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to central: ");
    // Print the central's MAC address
    Serial.println(central.address());

    // Turn the LED on (HIGH is the voltage level)
    digitalWrite(LED_BUILTIN, HIGH);

    while (central.connected()) {
      // Data Interval Setup - better than using delay function
      unsigned long timePassed = millis();

      // Output data values every tenth of a second
      for (int i = 1; i <= inferenceUpdateInterval / sensorUpdateInterval; i++) {

        // Derrive all values for char array and float array
        IMU.readAcceleration(x, y, z);
        accelX = round(x*10*9.81);
        accelY = round(y*10*9.81);
        accelZ = round(z*10*9.81);
        IMU.readGyroscope(x2, y2, z2);
        gyroX = round(x);
        gyroY = round(y);
        gyroZ = round(z);
        IMU.readMagneticField(magx, magy, magz);

        // Calculating the inclination based on accelerometer data x axis
        thetaM = atan2(x, z) * (180 / PI);
        // Calculating the inclination based on accelerometer data y axis
        phiM = atan2(y, z) * (180 / PI);
        // Calculate the New Phi value based on the measured Phi and old Phi

        dt = (millis() - timePassed) / 1000;
        // Reset the time
        timePassed = millis();
        // Calculate the new Theta angle based on gyroscope
        thetaG = thetaG + y2 * dt;
        // Calculate the new Phi angle based on gyroscope
        phiG = phiG - x2 * dt;

        // Apply complementary filter, gyro high pass, accel low pass to account for gyro drift long term
        // Estimated values with low lag and high resistance to noise due to acceleration
        phi = ((phi + y2 * dt) * .94) + (thetaM * .06);
        theta = ((theta - x2 * dt) * .94) + (phiM * .06);
        roll = round(abs(theta));
        pitch = round(abs(phi)) - 90;

        // Yaw Calculation from Library - Calibrated
        doNMeasurements (50, magx, magy, magz);
        float psi = atan2(magy, magx) * 180 / PI;
        // Taking absolute value due to the range of integer values able to be represented by 8 bit values. 
        yaw = round(abs(psi));

        signed char charArray[5] = {accelX, accelY, accelZ, pitch, yaw};
        float valueArray[6] = {x, y, z, theta, phi, psi};
        int valueArraySize = sizeof(valueArray) / sizeof(float);

        // Assign Values to Services
        customArrayChar.writeValue(charArray, sizeof(charArray));

        // Print float values at eachtime step
        int arrayLength = sizeof(valueArray) / sizeof(float);
        for (int i = 0; i <= (arrayLength - 1); i++) {
          Serial.print(valueArray[i]);
          Serial.print(" ");
        }
        // Ensure data output every tenth of second
        delay(sensorUpdateInterval);
        Serial.print("\n");
        arrayCount++;
      }

      // Inference is made here every 2 seconds
      // Allocate a buffer here for the values we'll read from the IMU
      float buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE] = { 0 };

      for (size_t ix = 0; ix < EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE; ix += 3) {
        // Determine the next tick (and then sleep later)
        uint64_t next_tick = micros() + (EI_CLASSIFIER_INTERVAL_MS * 1000);

        IMU.readAcceleration(buffer[ix], buffer[ix + 1], buffer[ix + 2]);

        for (int i = 0; i < 3; i++) {
          if (fabs(buffer[ix + i]) > MAX_ACCEPTED_RANGE) {
            buffer[ix + i] = ei_get_sign(buffer[ix + i]) * MAX_ACCEPTED_RANGE;
          }
        }

        buffer[ix + 0] *= CONVERT_G_TO_MS2;
        buffer[ix + 1] *= CONVERT_G_TO_MS2;
        buffer[ix + 2] *= CONVERT_G_TO_MS2;

        delayMicroseconds(next_tick - micros());
      }

      // Turn the raw buffer in a signal which we can the classify
      signal_t signal;
      int err = numpy::signal_from_buffer(buffer, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, &signal);
      if (err != 0) {
        ei_printf("Failed to create signal from buffer (%d)\n", err);
        return;
      }

      // Run the classifier
      ei_impulse_result_t result = { 0 };

      err = run_classifier(&signal, &result, debug_nn);
      if (err != EI_IMPULSE_OK) {
        ei_printf("ERR: Failed to run classifier (%d)\n", err);
        return;
      }

      // print the predictions
      ei_printf("Predictions ");
      ei_printf("(DSP: %d ms., Classification: %d ms., Anomaly: %d ms.)",
                result.timing.dsp, result.timing.classification, result.timing.anomaly);
      ei_printf(": \n");
      for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
        ei_printf("    %s: %.5f\n", result.classification[ix].label, result.classification[ix].value);
      }
      int maxValue = 0;
      int maxLabel = 0;
      for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
        ei_printf("    %s: %.5f\n", result.classification[ix].label, result.classification[ix].value);
        if (maxValue < result.classification[ix].value) {
          maxValue = result.classification[ix].value;
          maxLabel = ix + 1;
        }
      }
      customXChar.writeValue(maxLabel);
    }
  }
  if (central.disconnect()) {
    // Turn off LED and alert disconnect
    digitalWrite(LED_BUILTIN, LOW);
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}

//Average measurements to reduce noise
void doNMeasurements(unsigned int N, float& averX, float& averY, float& averZ) {
  float x, y, z;
  averX = 0; averY = 0; averZ = 0;
  for (int i = 1; i <= N; i++)
  { while (!IMU.magnetAvailable());
    IMU.readMagnet(x, y, z);
    averX += x; averY += y;  averZ += z;
  }
  averX /= N;    averY /= N;  averZ /= N;
}
