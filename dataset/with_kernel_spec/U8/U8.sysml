package HybrotSystemModel {
    attribute def Real;
    attribute def Integer;
    attribute def Boolean;
    
    attribute def LengthValue;
    attribute def AngleValue;
    attribute def ElectricPotentialValue;
    attribute def FrequencyValue;
    attribute def DurationValue;
    attribute def SpeedValue;
    attribute def ThermodynamicTemperatureValue;

    item def ProximitySensorData {
        attribute distance : LengthValue;
        attribute direction : AngleValue;
    }

    item def NeuralStimulusPattern {
        attribute electrodeChannel : Integer;
        attribute amplitude : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
        attribute duration : DurationValue;
    }

    item def NeuralResponsePattern {
        attribute electrodeChannel : Integer;
        attribute spikeRate : FrequencyValue;
    }

    item def MotorCommand {
        attribute leftWheelSpeed : SpeedValue;
        attribute rightWheelSpeed : SpeedValue;
    }

    item def BatteryStatus {
        attribute chargeLevel : Real;
        attribute voltage : ElectricPotentialValue;
    }

    item def LifeSupportStatus {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pH : Real;
        attribute oxygenLevel : Real;
        attribute nutrientLevel : Real;
    }

    part def BiologicalBrain {
        port stimulusIn {
            in stimulus : NeuralStimulusPattern;
        }
        port responseOut {
            out response : NeuralResponsePattern;
        }
    }

    part def LifeSupportSystem {
        port statusOut {
            out status : LifeSupportStatus;
        }
        action regulateEnvironment;
    }

    part def ProximitySensor {
        port dataOut {
            out data : ProximitySensorData;
        }
    }

    part def Wheel {
        port commandIn {
            in speed : SpeedValue;
        }
    }

    part def Battery {
        port statusOut {
            out status : BatteryStatus;
        }
    }

    part def RoboticBody {
        port sensorDataOut {
            out sensorData : ProximitySensorData;
        }
        port motorCommandIn {
            in command : MotorCommand;
        }
        port batteryStatusOut {
            out batteryStatus : BatteryStatus;
        }

        part leftWheel : Wheel;
        part rightWheel : Wheel;
        part frontSensor : ProximitySensor;
        part battery : Battery;

        bind batteryStatusOut = battery.statusOut;
    }

    part def MicroelectrodeArray {
        port processorStimulusIn {
            in stimulus : NeuralStimulusPattern;
        }
        port brainStimulusOut {
            out stimulus : NeuralStimulusPattern;
        }
        port brainResponseIn {
            in response : NeuralResponsePattern;
        }
        port processorResponseOut {
            out response : NeuralResponsePattern;
        }
    }

    part def SignalProcessingUnit {
        port sensorDataIn {
            in sensorData : ProximitySensorData;
        }
        port batteryStatusIn {
            in batteryStatus : BatteryStatus;
        }
        port lifeSupportStatusIn {
            in lifeSupportStatus : LifeSupportStatus;
        }
        port stimulusOut {
            out stimulus : NeuralStimulusPattern;
        }
        port responseIn {
            in response : NeuralResponsePattern;
        }
        port motorCommandOut {
            out motorCommand : MotorCommand;
        }

        action encodeSensorToStimulus {
            action acceptSensorData accept sd : ProximitySensorData via sensorDataIn;
            then action sendStimulus send new NeuralStimulusPattern() to stimulusOut;
        }

        action decodeResponseToMotor {
            action acceptNeuralResponse accept nr : NeuralResponsePattern via responseIn;
            then action sendMotorCommand send new MotorCommand() to motorCommandOut;
        }
    }

    state def OperationalStates {
        in obstacle : Boolean;
        in lowBattery : Boolean;
        
        state initialization;
        transition first initialization then active;
        
        state active {
            state exploring;
            state avoidingObstacle;
            transition first exploring
                if obstacle == true
                then avoidingObstacle;
            transition first avoidingObstacle
                if obstacle == false
                then exploring;
        }
        
        state maintenance;
        
        transition first active
            if lowBattery == true
            then maintenance;
        transition first maintenance
            if lowBattery == false
            then active;
    }

    part def Hybrot;

    part hybrot : Hybrot {
        attribute obstacleDetected : Boolean;
        attribute batteryLow : Boolean;
        
        part brain : BiologicalBrain;
        part lifeSupport : LifeSupportSystem;
        part body : RoboticBody;
        part mea : MicroelectrodeArray;
        part spu : SignalProcessingUnit;

        flow sensorDataFlow of ProximitySensorData 
            from body.sensorDataOut.sensorData to spu.sensorDataIn.sensorData;

        flow stimulusToMEAFlow of NeuralStimulusPattern 
            from spu.stimulusOut.stimulus to mea.processorStimulusIn.stimulus;

        flow stimulusToBrainFlow of NeuralStimulusPattern 
            from mea.brainStimulusOut.stimulus to brain.stimulusIn.stimulus;

        flow responseToMEAFlow of NeuralResponsePattern 
            from brain.responseOut.response to mea.brainResponseIn.response;

        flow responseToSPUFlow of NeuralResponsePattern 
            from mea.processorResponseOut.response to spu.responseIn.response;

        flow motorCommandFlow of MotorCommand 
            from spu.motorCommandOut.motorCommand to body.motorCommandIn.command;

        flow batteryStatusFlow of BatteryStatus 
            from body.batteryStatusOut.batteryStatus to spu.batteryStatusIn.batteryStatus;

        flow lifeSupportStatusFlow of LifeSupportStatus 
            from lifeSupport.statusOut.status to spu.lifeSupportStatusIn.lifeSupportStatus;

        exhibit OperationalStates {
            in obstacle = obstacleDetected;
            in lowBattery = batteryLow;
        }
    }

    requirement autonomousNavigation {
        text "The Hybrot shall autonomously navigate its environment using decisions generated by the living biological neural network.";
    }

    requirement obstacleAvoidance {
        text "The Hybrot shall detect obstacles using proximity sensors and convert neural responses into motor commands that avoid collisions.";
    }

    requirement lifeSupportMaintenance {
        text "The life support system shall maintain temperature, pH, oxygen, and nutrient levels within ranges that keep the biological neurons healthy and responsive.";
    }

    requirement batteryManagement {
        text "The Hybrot shall enter maintenance mode when the battery charge is low or when the life support system requires attention.";
    }
}
