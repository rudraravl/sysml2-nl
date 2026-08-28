package HybrotSystem {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---- Value Types ----
    value type Temperature :> RealValue { unit "°C"; }
    value type pHValue :> RealValue { unit "pH"; }
    value type OxygenConcentration :> RealValue { unit "percent"; }
    value type NutrientFlowRate :> RealValue { unit "mL/h"; }
    value type Voltage :> RealValue { unit "V"; }
    value type Current :> RealValue { unit "A"; }
    value type Distance :> RealValue { unit "m"; }
    value type BatteryCharge :> RealValue { unit "percent"; }
    value type AngularSpeed :> RealValue { unit "rad/s"; }
    value type Frequency :> RealValue { unit "Hz"; }
    value type DurationValue :> RealValue { unit "s"; }
    value type SpikeRate :> RealValue { unit "spikes/s"; }

    // ---- Item Definitions ----
    item def NeuralActivity {
        attribute spikeRate : SpikeRate;
        attribute channelPattern : Integer[0..*];
        attribute timestamp : TimeValue;
    }

    item def ElectricalStimulus {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute duration : DurationValue;
        attribute electrodePattern : Integer[0..*];
    }

    item def SensorData {
        attribute frontDistance : Distance;
        attribute leftDistance : Distance;
        attribute rightDistance : Distance;
        attribute timestamp : TimeValue;
    }

    item def MotorCommand {
        attribute leftWheelSpeed : AngularSpeed;
        attribute rightWheelSpeed : AngularSpeed;
        attribute commandId : Integer;
    }

    item def LifeSupportStatus {
        attribute temperature : Temperature;
        attribute pH : pHValue;
        attribute oxygen : OxygenConcentration;
        attribute nutrientFlow : NutrientFlowRate;
        attribute healthy : Boolean;
    }

    item def PowerStatus {
        attribute chargeLevel : BatteryCharge;
        attribute voltage : Voltage;
        attribute currentDraw : Current;
    }

    // ---- Port Definitions ----
    port def SensorDataOut {
        out sensorData : SensorData;
    }

    port def SensorDataIn {
        in sensorData : SensorData;
    }

    port def MotorCommandIn {
        in motorCommand : MotorCommand;
    }

    port def MotorCommandOut {
        out motorCommand : MotorCommand;
    }

    port def NeuralActivityOut {
        out neuralActivity : NeuralActivity;
    }

    port def NeuralActivityIn {
        in neuralActivity : NeuralActivity;
    }

    port def StimulusIn {
        in stimulus : ElectricalStimulus;
    }

    port def StimulusOut {
        out stimulus : ElectricalStimulus;
    }

    port def LifeSupportStatusOut {
        out status : LifeSupportStatus;
    }

    port def PowerStatusOut {
        out powerStatus : PowerStatus;
    }

    // ---- Interface Definitions ----
    interface def SensorDataInterface {
        end supplier : SensorDataOut;
        end consumer : SensorDataIn;
        flow of SensorData from supplier.sensorData to consumer.sensorData;
    }

    interface def MotorCommandInterface {
        end supplier : MotorCommandOut;
        end consumer : MotorCommandIn;
        flow of MotorCommand from supplier.motorCommand to consumer.motorCommand;
    }

    interface def NeuralActivityInterface {
        end supplier : NeuralActivityOut;
        end consumer : NeuralActivityIn;
        flow of NeuralActivity from supplier.neuralActivity to consumer.neuralActivity;
    }

    interface def StimulusInterface {
        end supplier : StimulusOut;
        end consumer : StimulusIn;
        flow of ElectricalStimulus from supplier.stimulus to consumer.stimulus;
    }

    interface def LifeSupportStatusInterface {
        end supplier : LifeSupportStatusOut;
        end consumer : LifeSupportStatusOut;
        flow of LifeSupportStatus from supplier.status to consumer.status;
    }

    // ---- Biological Brain ----
    part def BiologicalBrain {
        attribute cultureAgeDays : RealValue;
        attribute cellDensity : RealValue;
        attribute viability : Boolean;
        port recordingOut : NeuralActivityOut;
        port stimulationIn : StimulusIn;
        port lifeSupportIn : LifeSupportStatusOut;

        action def ProcessStimulus {
            in stimulus : ElectricalStimulus;
            out response : NeuralActivity;
        }

        state def NeuralStates {
            entry; then Resting;
            state Resting {
                entry;
            }
            state Active {
                entry;
            }
            state Fatigued {
                entry;
            }
            transition Resting_to_Active first Resting if stimulationIn.stimulus.amplitude > 0.0 then Active;
            transition Active_to_Resting first Active if stimulationIn.stimulus.amplitude == 0.0 then Resting;
            transition Active_to_Fatigued first Active if cultureAgeDays > 14.0 then Fatigued;
            transition Fatigued_to_Resting first Fatigued if lifeSupportIn.status.healthy == true then Resting;
        }
    }

    // ---- Life Support System ----
    part def LifeSupportSystem {
        attribute targetTemperature : Temperature = 37.0;
        attribute targetpH : pHValue = 7.4;
        attribute targetOxygen : OxygenConcentration = 95.0;
        attribute targetNutrientFlow : NutrientFlowRate = 0.5;
        attribute heaterOn : Boolean;
        attribute pumpOn : Boolean;
        port statusOut : LifeSupportStatusOut;

        action def RegulateTemperature {
            in currentTemp : Temperature;
            out adjustedTemp : Temperature;
        }

        action def RegulatepH {
            in currentpH : pHValue;
            out adjustedpH : pHValue;
        }

        action def RegulateOxygen {
            in currentO2 : OxygenConcentration;
            out adjustedO2 : OxygenConcentration;
        }

        action def SupplyNutrients {
            in requiredFlow : NutrientFlowRate;
            out actualFlow : NutrientFlowRate;
        }

        state def LifeSupportStates {
            entry; then Nominal;
            state Nominal {
                entry;
            }
            state Adjusting {
                entry;
            }
            state Critical {
                entry;
            }
            transition Nominal_to_Adjusting first Nominal if statusOut.status.temperature < 36.5 or statusOut.status.temperature > 37.5 then Adjusting;
            transition Adjusting_to_Nominal first Adjusting if statusOut.status.temperature >= 36.5 and statusOut.status.temperature <= 37.5 then Nominal;
            transition Nominal_to_Critical first Nominal if statusOut.status.oxygen < 80.0 then Critical;
            transition Critical_to_Adjusting first Critical if statusOut.status.oxygen >= 80.0 then Adjusting;
        }
    }

    // ---- Robotic Body ----
    part def RoboticBody {
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        part frontSensor : ProximitySensor;
        part leftSensor : ProximitySensor;
        part rightSensor : ProximitySensor;
        part battery : Battery;
        port sensorOut : SensorDataOut;
        port motorIn : MotorCommandIn;
        port powerOut : PowerStatusOut;

        part def Wheel {
            attribute speed : AngularSpeed;
            attribute direction : Integer;
            attribute maxSpeed : AngularSpeed = 10.0;
        }

        part def ProximitySensor {
            attribute maxRange : Distance = 0.5;
            attribute detectedDistance : Distance;
            attribute active : Boolean;
        }

        part def Battery {
            attribute chargeLevel : BatteryCharge = 100.0;
            attribute capacity : Current = 2.0;
            attribute nominalVoltage : Voltage = 12.0;
            port powerStatusOut : PowerStatusOut;
        }

        action def SenseEnvironment {
            out data : SensorData;
        }

        action def DriveMotors {
            in command : MotorCommand;
        }
    }

    // ---- Microelectrode Array ----
    part def MicroelectrodeArray {
        attribute electrodeCount : Integer = 60;
        attribute samplingRate : Frequency = 30000.0;
        attribute impedance : RealValue;
        port neuralOut : NeuralActivityOut;
        port stimulusIn : StimulusIn;
        port stimulusOut : StimulusOut;
        port neuralActivityOut : NeuralActivityOut;

        action def RecordNeuralActivity {
            in rawSignals : RealValue[0..*];
            out activity : NeuralActivity;
        }

        action def DeliverStimulus {
            in stim : ElectricalStimulus;
            out deliveredStim : ElectricalStimulus;
        }

        state def ElectrodeStates {
            entry; then Listening;
            state Listening {
                entry;
            }
            state Stimulating {
                entry;
            }
            state Bidirectional {
                entry;
            }
            transition Listening_to_Stimulating first Listening if stimulusIn.stimulus.amplitude > 0.0 then Stimulating;
            transition Stimulating_to_Listening first Stimulating if stimulusIn.stimulus.amplitude == 0.0 then Listening;
            transition Listening_to_Bidirectional first Listening if stimulusIn.stimulus.amplitude > 0.0 and neuralOut.neuralActivity.spikeRate > 0.0 then Bidirectional;
            transition Bidirectional_to_Listening first Bidirectional if stimulusIn.stimulus.amplitude == 0.0 then Listening;
        }
    }

    // ---- Signal Processing Unit ----
    part def SignalProcessingUnit {
        attribute samplingRate : Frequency = 30000.0;
        attribute decodingModel : String;
        attribute encodingModel : String;
        port sensorIn : SensorDataIn;
        port stimulusOut : StimulusOut;
        port neuralIn : NeuralActivityIn;
        port motorOut : MotorCommandOut;

        action def EncodeStimulus {
            in data : SensorData;
            out stimulus : ElectricalStimulus;
        }

        action def DecodeMotorCommand {
            in activity : NeuralActivity;
            out command : MotorCommand;
        }

        action def CalibrationRoutine {
            out calibrationComplete : Boolean;
        }

        state def ProcessorStates {
            entry; then Idle;
            state Idle {
                entry;
            }
            state Encoding {
                entry;
            }
            state Decoding {
                entry;
            }
            transition Idle_to_Encoding first Idle if sensorIn.sensorData.frontDistance < 0.5 then Encoding;
            transition Encoding_to_Decoding first Encoding if stimulusOut.stimulus.amplitude > 0.0 then Decoding;
            transition Decoding_to_Idle first Decoding if motorOut.motorCommand.commandId > 0 then Idle;
        }
    }

    // ---- Hybrot System ----
    part def Hybrot {
        attribute systemId : String;
        attribute operational : Boolean;
        part brain : BiologicalBrain;
        part lifeSupport : LifeSupportSystem;
        part body : RoboticBody;
        part electrodeArray : MicroelectrodeArray;
        part signalProcessor : SignalProcessingUnit;

        interface sensorToProcessor : SensorDataInterface connect body.sensorOut to signalProcessor.sensorIn;
        interface processorToElectrode : StimulusInterface connect signalProcessor.stimulusOut to electrodeArray.stimulusIn;
        interface electrodeToBrain : StimulusInterface connect electrodeArray.stimulusOut to brain.stimulationIn;
        interface brainToElectrode : NeuralActivityInterface connect brain.recordingOut to electrodeArray.neuralOut;
        interface electrodeToProcessor : NeuralActivityInterface connect electrodeArray.neuralActivityOut to signalProcessor.neuralIn;
        interface processorToMotor : MotorCommandInterface connect signalProcessor.motorOut to body.motorIn;
        interface lifeSupportToBrain : LifeSupportStatusInterface connect lifeSupport.statusOut to brain.lifeSupportIn;

        action def SenseAndStimulate {
            in sensorInput : SensorData;
            out stimulus : ElectricalStimulus;
        }

        action def RespondAndMove {
            in neuralResponse : NeuralActivity;
            out motorCmd : MotorCommand;
        }

        state def HybrotOperationalStates {
            entry; then Initializing;
            state Initializing {
                entry;
                // Calibration and culture stability check
            }
            state ActiveNavigation {
                entry; then Exploring;
                state Exploring {
                    entry;
                }
                state Avoiding {
                    entry;
                }
                transition Explore_to_Avoid first Exploring if body.frontSensor.detectedDistance < 0.3 then Avoiding;
                transition Avoid_to_Explore first Avoiding if body.frontSensor.detectedDistance > 0.5 then Exploring;
            }
            state Maintenance {
                entry;
                // Recharging and biological care
            }
            state Emergency {
                entry;
            }
            transition Init_to_Active first Initializing if brain.viability == true and brain.cultureAgeDays > 7.0 then ActiveNavigation;
            transition Active_to_Maintenance first ActiveNavigation if body.battery.chargeLevel < 20.0 then Maintenance;
            transition Maintenance_to_Active first Maintenance if body.battery.chargeLevel > 90.0 and brain.viability == true then ActiveNavigation;
            transition Active_to_Emergency first ActiveNavigation if lifeSupport.statusOut.status.healthy == false then Emergency;
            transition Emergency_to_Maintenance first Emergency if lifeSupport.statusOut.status.healthy == true then Maintenance;
        }
    }

    // ---- Requirements ----
    requirement def LifeSupportRequirement {
        subject lifeSupport : LifeSupportSystem;
        doc "The life support system shall maintain the biological brain environment within viable ranges.";
        objective {
            lifeSupport.targetTemperature >= 36.5 and lifeSupport.targetTemperature <= 37.5 and
            lifeSupport.targetpH >= 7.2 and lifeSupport.targetpH <= 7.6 and
            lifeSupport.targetOxygen >= 90.0 and lifeSupport.targetOxygen <= 100.0 and
            lifeSupport.targetNutrientFlow >= 0.1 and lifeSupport.targetNutrientFlow <= 1.0;
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        subject hybrot : Hybrot;
        doc "The Hybrot shall avoid obstacles detected within 0.3 meters by changing direction.";
        objective {
            hybrot.body.frontSensor.maxRange >= 0.3;
        }
    }

    requirement def BatteryLifeRequirement {
        subject body : RoboticBody;
        doc "The battery shall provide at least 2 hours of continuous operation under nominal load.";
        objective {
            body.battery.capacity >= 2.0;
        }
    }

    requirement def NeuralInterfaceRequirement {
        subject electrodeArray : MicroelectrodeArray;
        doc "The microelectrode array shall simultaneously record from and stimulate at least 60 electrodes.";
        objective {
            electrodeArray.electrodeCount >= 60;
        }
    }

    requirement def SignalProcessingRequirement {
        subject signalProcessor : SignalProcessingUnit;
        doc "The signal processing unit shall encode sensor data into stimuli and decode neural activity into motor commands within 100 milliseconds.";
        objective {
            signalProcessor.samplingRate >= 10000.0;
        }
    }

    requirement def OperationalStateRequirement {
        subject hybrot : Hybrot;
        doc "The Hybrot shall transition through initialization, active navigation, and maintenance states based on culture stability, obstacle proximity, and battery level.";
        objective {
            hybrot.operational == true;
        }
    }

    // ---- Verification ----
    verification def VerifyLifeSupport {
        subject lifeSupport : LifeSupportSystem;
        objective {
            lifeSupport.targetTemperature >= 36.5 and lifeSupport.targetTemperature <= 37.5;
        }
    }

    verification def VerifyObstacleAvoidance {
        subject hybrot : Hybrot;
        objective {
            hybrot.body.frontSensor.maxRange >= 0.3;
        }
    }

    verification def VerifyBatteryLife {
        subject body : RoboticBody;
        objective {
            body.battery.capacity >= 2.0;
        }
    }
}
