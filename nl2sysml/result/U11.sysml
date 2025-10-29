// Design a patient monitoring device that tracks vital signs and sends alerts.
```sysml
package PatientMonitoringDevice {

  // Define the types of data (items) that flow between parts
  item VitalSignData {
    attribute heartRate : Integer;
    attribute bloodPressureSystolic : Integer;
    attribute bloodPressureDiastolic : Integer;
    attribute temperature : Real;
    attribute oxygenSaturation : Real;
  }

  item AlertSignal {
    attribute alertType : String; // e.g., "HighHeartRate", "LowOxygen"
    attribute timestamp : DateTime;
    attribute patientId : String;
  }

  item DisplayData {
    attribute currentVitals : VitalSignData;
    attribute statusMessage : String;
  }

  item Power; // Represents electrical power

  // Define the individual parts (components) of the device
  part SensorArray {
    output vitalSignsOut : VitalSignData;
    input powerIn : Power;
  }

  part Processor {
    input vitalSignsIn : VitalSignData;
    output alertOut : AlertSignal;
    output displayOut : DisplayData;
    input powerIn : Power;
  }

  part CommunicationModule {
    input alertIn : AlertSignal;
    input powerIn : Power;
  }

  part Display {
    input displayIn : DisplayData;
    input powerIn : Power;
  }

  part PowerSource {
    output powerOut : Power;
  }

  // Define the top-level patient monitoring device
  part PatientMonitoringDevice {
    // Declare the sub-parts contained within the device
    part sensorArray : SensorArray;
    part processor : Processor;
    part communicationModule : CommunicationModule;
    part display : Display;
    part powerSource : PowerSource;

    // Define the flows of data and power between the sub-parts
    flow vitalSignFlow : VitalSignData from sensorArray.vitalSignsOut to processor.vitalSignsIn;
    flow alertFlow : AlertSignal from processor.alertOut to communicationModule.alertIn;
    flow displayFlow : DisplayData from processor.displayOut to display.displayIn;

    flow powerToSensors : Power from powerSource.powerOut to sensorArray.powerIn;
    flow powerToProcessor : Power from powerSource.powerOut to processor.powerIn;
    flow powerToComm : Power from powerSource.powerOut to communicationModule.powerIn;
    flow powerToDisplay : Power from powerSource.powerOut to display.powerIn;
  }

  // Define requirements for the device
  requirement TrackVitalSigns {
    text "The device shall track heart rate, blood pressure, temperature, and oxygen saturation.";
    satisfy sensorArray;
    satisfy processor;
  }

  requirement SendAlerts {
    text "The device shall send alerts when vital signs exceed predefined thresholds.";
    satisfy processor;
    satisfy communicationModule;
  }

  requirement DisplayVitals {
    text "The device shall display current vital signs and device status.";
    satisfy processor;
    satisfy display;
  }

  requirement Portable {
    text "The device shall be portable and battery-powered.";
    satisfy PatientMonitoringDevice;
  }

  requirement AccurateMeasurement {
    text "The device shall measure vital signs with an accuracy of X%."; // Placeholder for specific value
    satisfy sensorArray;
  }
}
```
