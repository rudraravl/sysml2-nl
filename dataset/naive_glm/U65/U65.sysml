package GastricBalloonSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def PressureValue :> Real { unit 'mmHg'; }
    value def VolumeValue :> Real { unit 'mL'; }
    value def TemperatureValue :> Real { unit 'degC'; }
    value def MassValue :> Real { unit 'kg'; }
    value def DurationValue :> Real { unit 'day'; }
    value def FlowRateValue :> Real { unit 'mL/min'; }

    // ===== Item Types =====
    item def SalineSolution {
        attribute concentration : Real = 0.9 [percent];
        attribute sterility : Boolean = true;
    }
    item def SensorReading {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : DurationValue;
    }
    item def ControlCommand {
        attribute commandKind : CommandKind;
    }
    enum def CommandKind { inflate; deflate; hold; abort; }
    item def SafetyAlert {
        attribute alertType : AlertType;
        attribute severity : Integer;
        attribute message : String;
    }
    enum def AlertType { overPressure; underPressure; overVolume; temperatureExcursion; leakDetected; ruptureRisk; }

    // ===== Port Definitions =====
    port def FluidPort {
        out item salineOut : SalineSolution;
        in item salineIn : SalineSolution;
        attribute flowRate : FlowRateValue;
    }
    port def DataPort {
        out item reading : SensorReading;
    }
    port def CommandPort {
        in item command : ControlCommand;
        out item ack : ControlCommand;
    }
    port def AlertPort {
        out item alert : SafetyAlert;
    }

    // ===== Requirements =====
    package Requirements {
        requirement def WeightLossRequirement {
            doc "The system shall support a target weight loss of 10-15% over a six-month treatment period.";
            attribute minLossPercent : Real = 10;
            attribute maxLossPercent : Real = 15;
            attribute treatmentDuration : DurationValue = 180;
        }
        requirement def FillVolumeRequirement {
            doc "The balloon shall be fillable to a precise volume between 400 and 700 mL.";
            attribute minVolume : VolumeValue = 400;
            attribute maxVolume : VolumeValue = 700;
        }
        requirement def SafetyThresholdRequirement {
            doc "The system shall trigger safety alerts when sensor readings exceed predefined safe thresholds.";
            attribute maxSafePressure : PressureValue = 20;
            attribute minSafePressure : PressureValue = 5;
            attribute maxSafeTemperature : TemperatureValue = 38;
            attribute minSafeTemperature : TemperatureValue = 34;
        }
        requirement def BiocompatibilityRequirement {
            doc "The balloon shall be made of biocompatible materials safe for gastric residence up to 6 months.";
            attribute residenceDuration : DurationValue = 180;
        }
        requirement def EndoscopicDeploymentRequirement {
            doc "The balloon shall be insertable and removable via endoscopy in a deflated state.";
        }
    }

    // ===== Part Definitions =====
    part def PressureSensor {
        port dataOut : DataPort;
        attribute measuredPressure : PressureValue;
        attribute samplingRate : Real = 1 [Hz];
        action def sense : SensorReading {
            // continuously sample pressure
        }
    }
    part def VolumeSensor {
        port dataOut : DataPort;
        attribute measuredVolume : VolumeValue;
        attribute samplingRate : Real = 1 [Hz];
    }
    part def TemperatureSensor {
        port dataOut : DataPort;
        attribute measuredTemperature : TemperatureValue;
        attribute samplingRate : Real = 0.5 [Hz];
    }

    part def IntragastricBalloon {
        doc "Soft, durable, biocompatible intragastric balloon occupying gastric space to promote satiety.";
        attribute material : String = "medical-grade silicone";
        attribute maxCapacity : VolumeValue = 700;
        attribute currentVolume : VolumeValue = 0;
        attribute currentPressure : PressureValue = 0;
        attribute currentTemperature : TemperatureValue = 37;
        attribute isBiocompatible : Boolean = true;

        port fluidFill : FluidPort;
        port fluidDrain : FluidPort;
        port sensorData : DataPort;

        part pressureSensor : PressureSensor;
        part volumeSensor : VolumeSensor;
        part temperatureSensor : TemperatureSensor;

        state def BalloonLifecycle {
            entry; then Deflated;
            state Deflated;
            transition Deflated to Inserting
                when controlCommand.commandKind == CommandKind::inflate;
            state Inserting {
                entry { /* balloon advanced endoscopically into stomach */ }
            }
            transition Inserting to Inflating
                when positioned == true;
            state Inflating {
                entry { /* saline flows in via catheter */ }
            }
            transition Inflating to Deployed
                when currentVolume >= targetFillVolume;
            state Deployed {
                entry { /* continuous monitoring active */ }
            }
            transition Deployed to Deflating
                when controlCommand.commandKind == CommandKind::deflate
                or safetyAlert != null;
            state Deflating {
                entry { /* saline extracted via deflation pump */ }
            }
            transition Deflating to Removed
                when currentVolume <= 0;
            state Removed;
        }
        attribute positioned : Boolean = false;
        attribute targetFillVolume : VolumeValue = 550;
        attribute controlCommand : ControlCommand;
        attribute safetyAlert : SafetyAlert;
    }

    part def CatheterSystem {
        doc "Flexible catheter system for delivering and extracting saline between pump and balloon.";
        attribute length : Real = 150 [cm];
        attribute innerDiameter : Real = 2.5 [mm];
        attribute isFlexible : Boolean = true;
        port proximal : FluidPort;
        port distal : FluidPort;
        item flow : SalineSolution;
    }

    part def InflationPump {
        doc "External pump that pushes sterile saline through the catheter to fill the balloon.";
        attribute maxFlowRate : FlowRateValue = 50;
        attribute currentFlowRate : FlowRateValue = 0;
        attribute reservoirVolume : VolumeValue = 1000;
        port pumpOut : FluidPort;
        port cmdIn : CommandPort;
        state def PumpOperation {
            entry; then Idle;
            state Idle;
            transition Idle to Pumping
                when cmdIn.command.commandKind == CommandKind::inflate;
            state Pumping {
                entry { currentFlowRate = maxFlowRate; }
            }
            transition Pumping to Idle
                when cmdIn.command.commandKind == CommandKind::hold
                or targetReached == true;
            attribute targetReached : Boolean = false;
        }
    }

    part def DeflationPump {
        doc "Pump used to extract saline from the balloon at end of treatment or on safety issue.";
        attribute maxFlowRate : FlowRateValue = 40;
        attribute currentFlowRate : FlowRateValue = 0;
        port pumpIn : FluidPort;
        port cmdIn : CommandPort;
        state def DeflationPumpOperation {
            entry; then Idle;
            state Idle;
            transition Idle to Extracting
                when cmdIn.command.commandKind == CommandKind::deflate;
            state Extracting {
                entry { currentFlowRate = maxFlowRate; }
            }
            transition Extracting to Idle
                when balloonEmpty == true;
            attribute balloonEmpty : Boolean = false;
        }
    }

    part def MonitoringUnit {
        doc "Dedicated unit that receives sensor data and triggers safety alerts on threshold violations.";
        port sensorIn : DataPort[3];
        port alertOut : AlertPort;
        port cmdOut : CommandPort;

        attribute safePressureMin : PressureValue = 5;
        attribute safePressureMax : PressureValue = 20;
        attribute safeTempMin : TemperatureValue = 34;
        attribute safeTempMax : TemperatureValue = 38;
        attribute safeVolumeMax : VolumeValue = 700;

        attribute latestReading : SensorReading;
        attribute activeAlert : SafetyAlert;

        state def MonitoringState {
            entry; then Normal;
            state Normal {
                entry { activeAlert = null; }
            }
            transition Normal to Alert
                when latestReading.pressure > safePressureMax
                or latestReading.pressure < safePressureMin
                or latestReading.temperature > safeTempMax
                or latestReading.temperature < safeTempMin
                or latestReading.volume > safeVolumeMax;
            state Alert {
                entry { /* emit SafetyAlert */ }
            }
            transition Alert to Normal
                when latestReading.pressure <= safePressureMax
                and latestReading.pressure >= safePressureMin
                and latestReading.temperature <= safeTempMax
                and latestReading.temperature >= safeTempMin
                and latestReading.volume <= safeVolumeMax;
        }
    }

    part def ControlUnit {
        doc "Manages inflation/deflation commands to pumps and tracks overall treatment timeline.";
        port cmdToInflationPump : CommandPort;
        port cmdToDeflationPump : CommandPort;
        port cmdToBalloon : CommandPort;
        port alertIn : AlertPort;

        attribute treatmentDay : DurationValue = 0;
        attribute treatmentDuration : DurationValue = 180;
        attribute targetFillVolume : VolumeValue = 550;
        attribute currentPhase : String = "idle";

        state def ControlState {
            entry; then Idle;
            state Idle;
            transition Idle to Deploying
                when startDeployment == true;
            state Deploying {
                entry { /* send inflate command */ }
            }
            transition Deploying to Monitoring
                when balloonDeployed == true;
            state Monitoring {
                entry { /* track treatment timeline */ }
            }
            transition Monitoring to Deflating
                when treatmentDay >= treatmentDuration
                or alertIn.alert != null;
            state Deflating {
                entry { /* send deflate command */ }
            }
            transition Deflating to Complete
                when balloonRemoved == true;
            state Complete;
            attribute startDeployment : Boolean = false;
            attribute balloonDeployed : Boolean = false;
            attribute balloonRemoved : Boolean = false;
        }
    }

    part def PatientContext {
        doc "Patient context representing the host for the gastric balloon treatment.";
        attribute initialBodyMass : MassValue = 100;
        attribute targetLossPercent : Real = 12.5;
        attribute currentBodyMass : MassValue = 100;
        attribute stomachCapacity : VolumeValue = 1000;
    }

    // ===== System Assembly =====
    part def GastricBalloonSystem {
        doc "Complete gastric balloon system for minimally invasive weight-loss treatment.";

        part balloon : IntragastricBalloon {
            satisfy Requirements::FillVolumeRequirement;
            satisfy Requirements::BiocompatibilityRequirement;
            satisfy Requirements::EndoscopicDeploymentRequirement;
        }
        part catheter : CatheterSystem;
        part inflationPump : InflationPump;
        part deflationPump : DeflationPump;
        part monitoringUnit : MonitoringUnit {
            satisfy Requirements::SafetyThresholdRequirement;
        }
        part controlUnit : ControlUnit;
        part patient : PatientContext {
            satisfy Requirements::WeightLossRequirement;
        }

        // Fluid connections
        connection inflationPump.pumpOut to catheter.proximal;
        connection catheter.distal to balloon.fluidFill;
        connection balloon.fluidDrain to deflationPump.pumpIn;

        // Sensor data connections
        connection balloon.sensorData to monitoringUnit.sensorIn[1];
        connection balloon.pressureSensor.dataOut to monitoringUnit.sensorIn[2];
        connection balloon.temperatureSensor.dataOut to monitoringUnit.sensorIn[3];

        // Command connections
        connection controlUnit.cmdToInflationPump to inflationPump.cmdIn;
        connection controlUnit.cmdToDeflationPump to deflationPump.cmdIn;
        connection controlUnit.cmdToBalloon to balloon.fluidFill;

        // Alert connection
        connection monitoringUnit.alertOut to controlUnit.alertIn;

        // Internal balloon sensor bindings
        connection balloon.pressureSensor.dataOut to balloon.sensorData;
        connection balloon.volumeSensor.dataOut to balloon.sensorData;
        connection balloon.temperatureSensor.dataOut to balloon.sensorData;
    }
}

package GastricBalloonSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def PressureValue :> Real { unit 'mmHg'; }
    value def VolumeValue :> Real { unit 'mL'; }
    value def TemperatureValue :> Real { unit 'degC'; }
    value def MassValue :> Real { unit 'kg'; }
    value def DurationValue :> Real { unit 'day'; }
    value def FlowRateValue :> Real { unit 'mL/min'; }
    value def PercentValue :> Real { unit 'percent'; }

    // ===== Item Types =====
    item def SalineSolution {
        attribute concentration : PercentValue = 0.9;
        attribute sterility : Boolean = true;
        attribute volume : VolumeValue;
    }

    item def SensorReading {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : DurationValue;
    }

    enum def CommandKind { inflate; deflate; hold; abort; }
    item def ControlCommand {
        attribute commandKind : CommandKind;
        attribute targetVolume : VolumeValue;
    }

    enum def AlertType { overPressure; underPressure; overVolume; temperatureExcursion; leakDetected; ruptureRisk; }
    item def SafetyAlert {
        attribute alertType : AlertType;
        attribute severity : Integer;
        attribute message : String;
        attribute reading : SensorReading;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        out item salineOut : SalineSolution;
        in item salineIn : SalineSolution;
        attribute flowRate : FlowRateValue;
    }
    port def DataPort {
        out item reading : SensorReading;
    }
    port def CommandPort {
        in item command : ControlCommand;
        out item ack : ControlCommand;
    }
    port def AlertPort {
        out item alert : SafetyAlert;
    }

    // ===== Requirements =====
    package Requirements {
        requirement def WeightLossRequirement {
            doc "The system shall support a target weight loss of 10-15% over a six-month treatment period.";
            attribute minLossPercent : Real = 10;
            attribute maxLossPercent : Real = 15;
            attribute treatmentDuration : DurationValue = 180;
        }
        requirement def FillVolumeRequirement {
            doc "The balloon shall be fillable to a precise volume between 400 and 700 mL.";
            attribute minVolume : VolumeValue = 400;
            attribute maxVolume : VolumeValue = 700;
        }
        requirement def SafetyThresholdRequirement {
            doc "The system shall trigger safety alerts when sensor readings exceed predefined safe thresholds.";
            attribute maxSafePressure : PressureValue = 20;
            attribute minSafePressure : PressureValue = 5;
            attribute maxSafeTemperature : TemperatureValue = 38;
            attribute minSafeTemperature : TemperatureValue = 34;
            attribute maxSafeVolume : VolumeValue = 700;
        }
        requirement def BiocompatibilityRequirement {
            doc "The balloon shall be made of biocompatible materials safe for gastric residence up to 6 months.";
            attribute residenceDuration : DurationValue = 180;
        }
        requirement def EndoscopicDeploymentRequirement {
            doc "The balloon shall be insertable and removable via endoscopy in a deflated state.";
        }
        requirement def ContinuousMonitoringRequirement {
            doc "The system shall continuously monitor pressure, volume, and temperature throughout treatment.";
            attribute samplingRate : Real = 1.0;
        }
    }

    // ===== Sensor Part Definitions =====
    part def PressureSensor {
        port dataOut : DataPort;
        attribute measuredPressure : PressureValue;
        attribute samplingRate : Real = 1.0;
        action def sense {
            out reading : SensorReading;
        }
    }
    part def VolumeSensor {
        port dataOut : DataPort;
        attribute measuredVolume : VolumeValue;
        attribute samplingRate : Real = 1.0;
        action def sense {
            out reading : SensorReading;
        }
    }
    part def TemperatureSensor {
        port dataOut : DataPort;
        attribute measuredTemperature : TemperatureValue;
        attribute samplingRate : Real = 0.5;
        action def sense {
            out reading : SensorReading;
        }
    }

    // ===== Intragastric Balloon =====
    part def IntragastricBalloon {
        doc "Soft, durable, biocompatible intragastric balloon occupying gastric space to promote satiety.";
        attribute material : String = "medical-grade silicone";
        attribute maxCapacity : VolumeValue = 700;
        attribute currentVolume : VolumeValue = 0;
        attribute currentPressure : PressureValue = 0;
        attribute currentTemperature : TemperatureValue = 37;
        attribute isBiocompatible : Boolean = true;
        attribute positioned : Boolean = false;
        attribute targetFillVolume : VolumeValue = 550;
        attribute receivedCommand : ControlCommand;
        attribute receivedAlert : SafetyAlert;

        port fluidFill : FluidPort;
        port fluidDrain : FluidPort;
        port sensorData : DataPort;

        part pressureSensor : PressureSensor;
        part volumeSensor : VolumeSensor;
        part temperatureSensor : TemperatureSensor;

        state def BalloonLifecycle {
            entry; then Deflated;
            state Deflated {
                entry { currentVolume = 0; }
            }
            transition Deflated to Inserting
                when receivedCommand.commandKind == CommandKind::inflate;
            state Inserting {
                entry { positioned = false; }
                do { /* balloon advanced endoscopically into stomach */ }
            }
            transition Inserting to Inflating
                when positioned == true;
            state Inflating {
                entry { /* saline flows in via catheter from inflation pump */ }
                do { currentVolume = currentVolume + flowIncrement; }
            }
            transition Inflating to Deployed
                when currentVolume >= targetFillVolume;
            state Deployed {
                entry { /* continuous monitoring active */ }
                do { /* maintain volume, report sensor data */ }
            }
            transition Deployed to Deflating
                when receivedCommand.commandKind == CommandKind::deflate
                or receivedAlert != null;
            state Deflating {
                entry { /* saline extracted via deflation pump */ }
                do { currentVolume = currentVolume - flowDecrement; }
            }
            transition Deflating to Removed
                when currentVolume <= 0;
            state Removed {
                entry { /* deflated balloon removed via endoscopy */ }
            }
        }
        attribute flowIncrement : VolumeValue = 5;
        attribute flowDecrement : VolumeValue = 5;
    }

    // ===== Catheter System =====
    part def CatheterSystem {
        doc "Flexible catheter system for delivering and extracting saline between pump and balloon.";
        attribute length : Real = 150;
        attribute lengthUnit : String = "cm";
        attribute innerDiameter : Real = 2.5;
        attribute innerDiameterUnit : String = "mm";
        attribute isFlexible : Boolean = true;
        attribute isBiocompatible : Boolean = true;

        port proximal : FluidPort;
        port distal : FluidPort;

        item flow : SalineSolution;

        action def transmitFluid {
            in salineIn : SalineSolution;
            out salineOut : SalineSolution;
        }
    }

    // ===== Inflation Pump =====
    part def InflationPump {
        doc "External pump that pushes sterile saline through the catheter to fill the balloon.";
        attribute maxFlowRate : FlowRateValue = 50;
        attribute currentFlowRate : FlowRateValue = 0;
        attribute reservoirVolume : VolumeValue = 1000;
        attribute targetReached : Boolean = false;

        port pumpOut : FluidPort;
        port cmdIn : CommandPort;

        state def PumpOperation {
            entry; then Idle;
            state Idle {
                entry { currentFlowRate = 0; }
            }
            transition Idle to Pumping
                when cmdIn.command.commandKind == CommandKind::inflate;
            state Pumping {
                entry { currentFlowRate = maxFlowRate; }
                do { /* push saline through pumpOut */ }
            }
            transition Pumping to Idle
                when cmdIn.command.commandKind == CommandKind::hold
                or targetReached == true;
        }
    }

    // ===== Deflation Pump =====
    part def DeflationPump {
        doc "Pump used to extract saline from the balloon at end of treatment or on safety issue.";
        attribute maxFlowRate : FlowRateValue = 40;
        attribute currentFlowRate : FlowRateValue = 0;
        attribute balloonEmpty : Boolean = false;

        port pumpIn : FluidPort;
        port cmdIn : CommandPort;

        state def DeflationPumpOperation {
            entry; then Idle;
            state Idle {
                entry { currentFlowRate = 0; }
            }
            transition Idle to Extracting
                when cmdIn.command.commandKind == CommandKind::deflate;
            state Extracting {
                entry { currentFlowRate = maxFlowRate; }
                do { /* extract saline through pumpIn */ }
            }
            transition Extracting to Idle
                when balloonEmpty == true;
        }
    }

    // ===== Monitoring Unit =====
    part def MonitoringUnit {
        doc "Dedicated unit that receives sensor data and triggers safety alerts on threshold violations.";
        port sensorIn1 : DataPort;
        port sensorIn2 : DataPort;
        port sensorIn3 : DataPort;
        port alertOut : AlertPort;
        port cmdOut : CommandPort;

        attribute safePressureMin : PressureValue = 5;
        attribute safePressureMax : PressureValue = 20;
        attribute safeTempMin : TemperatureValue = 34;
        attribute safeTempMax : TemperatureValue = 38;
        attribute safeVolumeMax : VolumeValue = 700;

        attribute latestReading : SensorReading;
        attribute activeAlert : SafetyAlert;

        action def evaluateThresholds {
            in reading : SensorReading;
            out alert : SafetyAlert;
        }

        state def MonitoringState {
            entry; then Normal;
            state Normal {
                entry { activeAlert = null; }
                do { /* continuously read sensor data */ }
            }
            transition Normal to Alert
                when latestReading.pressure > safePressureMax
                or latestReading.pressure < safePressureMin
                or latestReading.temperature > safeTempMax
                or latestReading.temperature < safeTempMin
                or latestReading.volume > safeVolumeMax;
            state Alert {
                entry { /* emit SafetyAlert via alertOut */ }
                do { /* send abort command via cmdOut */ }
            }
            transition Alert to Normal
                when latestReading.pressure <= safePressureMax
                and latestReading.pressure >= safePressureMin
                and latestReading.temperature <= safeTempMax
                and latestReading.temperature >= safeTempMin
                and latestReading.volume <= safeVolumeMax;
        }
    }

    // ===== Control Unit =====
    part def ControlUnit {
        doc "Manages inflation/deflation commands to pumps and tracks overall treatment timeline.";
        port cmdToInflationPump : CommandPort;
        port cmdToDeflationPump : CommandPort;
        port cmdToBalloon : CommandPort;
        port alertIn : AlertPort;

        attribute treatmentDay : DurationValue = 0;
        attribute treatmentDuration : DurationValue = 180;
        attribute targetFillVolume : VolumeValue = 550;
        attribute currentPhase : String = "idle";
        attribute startDeployment : Boolean = false;
        attribute balloonDeployed : Boolean = false;
        attribute balloonRemoved : Boolean = false;

        action def manageTreatment {
            doc "Coordinates deployment, monitoring, and removal of the balloon over the treatment period.";
        }

        state def ControlState {
            entry; then Idle;
            state Idle {
                entry { currentPhase = "idle"; }
            }
            transition Idle to Deploying
                when startDeployment == true;
            state Deploying {
                entry {
                    currentPhase = "deploying";
                    /* send inflate command to inflation pump and balloon */
                }
            }
            transition Deploying to Monitoring
                when balloonDeployed == true;
            state Monitoring {
                entry { currentPhase = "monitoring"; }
                do { treatmentDay = treatmentDay + 1; }
            }
            transition Monitoring to Deflating
                when treatmentDay >= treatmentDuration
                or alertIn.alert != null;
            state Deflating {
                entry {
                    currentPhase = "deflating";
                    /* send deflate command to deflation pump and balloon */
                }
            }
            transition Deflating to Complete
                when balloonRemoved == true;
            state Complete {
                entry { currentPhase = "complete"; }
            }
        }
    }

    // ===== Patient Context =====
    part def PatientContext {
        doc "Patient context representing the host for the gastric balloon treatment.";
        attribute initialBodyMass : MassValue = 100;
        attribute targetLossPercent : Real = 12.5;
        attribute currentBodyMass : MassValue = 100;
        attribute stomachCapacity : VolumeValue = 1000;
        attribute satietyLevel : PercentValue = 0;

        action def consumeFood {
            in foodVolume : VolumeValue;
            out satiety : PercentValue;
        }
    }

    // ===== System Assembly =====
    part def GastricBalloonSystem {
        doc "Complete gastric balloon system for minimally invasive weight-loss treatment.";

        part balloon : IntragastricBalloon {
            satisfy Requirements::FillVolumeRequirement;
            satisfy Requirements::BiocompatibilityRequirement;
            satisfy Requirements::EndoscopicDeploymentRequirement;
        }
        part catheter : CatheterSystem;
        part inflationPump : InflationPump;
        part deflationPump : DeflationPump;
        part monitoringUnit : MonitoringUnit {
            satisfy Requirements::SafetyThresholdRequirement;
            satisfy Requirements::ContinuousMonitoringRequirement;
        }
        part controlUnit : ControlUnit;
        part patient : PatientContext {
            satisfy Requirements::WeightLossRequirement;
        }

        // Fluid connections: inflation path
        connection inflationPump.pumpOut to catheter.proximal;
        connection catheter.distal to balloon.fluidFill;

        // Fluid connections: deflation path
        connection balloon.fluidDrain to deflationPump.pumpIn;

        // Sensor data connections to monitoring unit
        connection balloon.sensorData to monitoringUnit.sensorIn1;
        connection balloon.pressureSensor.dataOut to monitoringUnit.sensorIn2;
        connection balloon.temperatureSensor.dataOut to monitoringUnit.sensorIn3;

        // Command connections from control unit
        connection controlUnit.cmdToInflationPump to inflationPump.cmdIn;
        connection controlUnit.cmdToDeflationPump to deflationPump.cmdIn;
        connection controlUnit.cmdToBalloon to balloon.fluidFill;

        // Alert connection from monitoring unit to control unit
        connection monitoringUnit.alertOut to controlUnit.alertIn;

        // Internal balloon sensor bindings
        connection balloon.pressureSensor.dataOut to balloon.sensorData;
        connection balloon.volumeSensor.dataOut to balloon.sensorData;
        connection balloon.temperatureSensor.dataOut to balloon.sensorData;
    }
}
