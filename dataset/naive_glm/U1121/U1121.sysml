package HVACBuildingAutomation {

    import ScalarValues::*;
    import ISQ::*;
    import ISQTime::*;

    // ===== Value Types with Units =====
    value type Temperature :> Real {
        unit 'degC';
    }

    value type Humidity :> Real {
        unit 'percentRH';
    }

    value type DamperPosition :> Real {
        unit 'percent';
    }

    value type FanSpeed :> Real {
        unit 'rpm';
    }

    value type SamplingInterval :> Real {
        unit 's';
    }

    value type BaudRate :> Integer {
        unit 'bps';
    }

    // ===== Item Definitions =====
    item def TemperatureReading {
        attribute value : Temperature;
        attribute nodeId : String;
        attribute zoneId : String;
        attribute timestamp : TimeValue;
    }

    item def HumidityReading {
        attribute value : Humidity;
        attribute nodeId : String;
        attribute zoneId : String;
        attribute timestamp : TimeValue;
    }

    item def DamperCommand {
        attribute position : DamperPosition;
        attribute targetNodeId : String;
        attribute zoneId : String;
    }

    item def FanCommand {
        attribute speed : FanSpeed;
        attribute targetNodeId : String;
        attribute zoneId : String;
    }

    item def DamperStatus {
        attribute currentPosition : DamperPosition;
        attribute nodeId : String;
        attribute motorFault : Boolean = false;
    }

    item def FanStatus {
        attribute currentSpeed : FanSpeed;
        attribute nodeId : String;
        attribute motorFault : Boolean = false;
    }

    // ===== Port Definitions =====
    port def LonWorksNetworkPort {
        attribute nodeId : String;
        in tempReadings : TemperatureReading[*];
        in humidityReadings : HumidityReading[*];
        in damperStatuses : DamperStatus[*];
        in fanStatuses : FanStatus[*];
        out tempReadingsOut : TemperatureReading[*];
        out humidityReadingsOut : HumidityReading[*];
        out damperCommands : DamperCommand[*];
        out fanCommands : FanCommand[*];
        out damperStatusOut : DamperStatus[*];
        out fanStatusOut : FanStatus[*];
    }

    // ===== Abstract Node =====
    part def LonWorksNode {
        attribute nodeId : String;
        attribute networkAddress : String;
        attribute protocol : String = "LonWorks";
        port networkPort : LonWorksNetworkPort;
    }

    // ===== Sensor Nodes =====
    part def SensorNode :> LonWorksNode {
        attribute samplingInterval : SamplingInterval = 5 [s];
        attribute zoneId : String;
    }

    part def TemperatureSensorNode :> SensorNode {
        attribute measuredTemperature : Temperature;
        attribute sensorAccuracy : Temperature = 0.5 [degC];

        action def takeTemperatureReading {
            in sensor : TemperatureSensorNode;
            out reading : TemperatureReading;
            perform {
                // Simulate ADC conversion of physical temperature
                assign reading.value := sensor.measuredTemperature;
                assign reading.nodeId := sensor.nodeId;
                assign reading.zoneId := sensor.zoneId;
            }
        }

        action def broadcastReading {
            in reading : TemperatureReading;
            in out port : LonWorksNetworkPort;
            perform {
                send reading to port.tempReadingsOut;
            }
        }

        state machine TemperatureSensorStateMachine {
            entry;
            state Idle;
            state Measuring;
            state Transmitting;

            transition from entry to Idle;

            transition from Idle to Measuring
                accept TimeTick;

            transition from Measuring to Transmitting
                when true;

            transition from Transmitting to Idle
                when true;
        }
    }

    part def HumiditySensorNode :> SensorNode {
        attribute measuredHumidity : Humidity;
        attribute sensorAccuracy : Humidity = 2 [percentRH];

        action def takeHumidityReading {
            in sensor : HumiditySensorNode;
            out reading : HumidityReading;
            perform {
                assign reading.value := sensor.measuredHumidity;
                assign reading.nodeId := sensor.nodeId;
                assign reading.zoneId := sensor.zoneId;
            }
        }

        action def broadcastReading {
            in reading : HumidityReading;
            in out port : LonWorksNetworkPort;
            perform {
                send reading to port.humidityReadingsOut;
            }
        }

        state machine HumiditySensorStateMachine {
            entry;
            state Idle;
            state Measuring;
            state Transmitting;

            transition from entry to Idle;

            transition from Idle to Measuring
                accept TimeTick;

            transition from Measuring to Transmitting
                when true;

            transition from Transmitting to Idle
                when true;
        }
    }

    // ===== HVAC Controller Node =====
    part def HVACControllerNode :> LonWorksNode {
        attribute zoneId : String;
        attribute temperatureSetpoint : Temperature = 22 [degC];
        attribute humiditySetpoint : Humidity = 50 [percentRH];
        attribute temperatureDeadband : Temperature = 1 [degC];
        attribute humidityDeadband : Humidity = 5 [percentRH];
        attribute currentTemperature : Temperature;
        attribute currentHumidity : Humidity;
        attribute lastDamperCommand : DamperPosition = 50 [percent];
        attribute lastFanCommand : FanSpeed = 1000 [rpm];

        action def updateCurrentConditions {
            in tempReading : TemperatureReading;
            in humidityReading : HumidityReading;
            in out currentTemp : Temperature;
            in out currentHum : Humidity;
            perform {
                assign currentTemp := tempReading.value;
                assign currentHum := humidityReading.value;
            }
        }

        action def computeControlResponse {
            in temp : Temperature;
            in humidity : Humidity;
            in tempSetpoint : Temperature;
            in humiditySetpoint : Humidity;
            in tempDeadband : Temperature;
            in humidityDeadband : Humidity;
            in damperFeedback : DamperStatus;
            in fanFeedback : FanStatus;
            out damperCmd : DamperCommand;
            out fanCmd : FanCommand;

            local tempError : Temperature;
            local humidityError : Humidity;
            local computedDamper : DamperPosition;
            local computedFan : FanSpeed;

            perform {
                assign tempError := temp - tempSetpoint;
                assign humidityError := humidity - humiditySetpoint;

                // Damper control: if too warm, open damper more for cooling airflow
                if tempError > tempDeadband {
                    assign computedDamper := 75 [percent];
                } else if tempError < (0 - tempDeadband) {
                    assign computedDamper := 25 [percent];
                } else {
                    assign computedDamper := 50 [percent];
                }

                // Fan speed control: if humidity too high, increase fan speed
                if humidityError > humidityDeadband {
                    assign computedFan := 1500 [rpm];
                } else if humidityError < (0 - humidityDeadband) {
                    assign computedFan := 800 [rpm];
                } else {
                    assign computedFan := 1000 [rpm];
                }

                assign damperCmd.position := computedDamper;
                assign damperCmd.targetNodeId := "damper_" + zoneId;
                assign damperCmd.zoneId := zoneId;

                assign fanCmd.speed := computedFan;
                assign fanCmd.targetNodeId := "fan_" + zoneId;
                assign fanCmd.zoneId := zoneId;
            }
        }

        action def sendCommands {
            in damperCmd : DamperCommand;
            in fanCmd : FanCommand;
            in out port : LonWorksNetworkPort;
            perform {
                send damperCmd to port.damperCommands;
                send fanCmd to port.fanCommands;
            }
        }

        action def evaluateStatus {
            in damperStatus : DamperStatus;
            in fanStatus : FanStatus;
            in expectedDamper : DamperPosition;
            in expectedFan : FanSpeed;
            out statusValid : Boolean;
            perform {
                assign statusValid := (damperStatus.currentPosition == expectedDamper)
                    and (fanStatus.currentSpeed == expectedFan);
            }
        }

        state machine ControllerStateMachine {
            entry;
            state WaitingForData;
            state Processing;
            state Commanding;
            state Monitoring;

            transition from entry to WaitingForData;

            transition from WaitingForData to Processing
                accept TemperatureReading;

            transition from WaitingForData to Processing
                accept HumidityReading;

            transition from Processing to Commanding
                when true;

            transition from Commanding to Monitoring
                when true;

            transition from Monitoring to WaitingForData
                when true;
        }
    }

    // ===== Actuator Nodes =====
    part def ActuatorNode :> LonWorksNode {
        attribute zoneId : String;
        attribute commandTimeout : SamplingInterval = 10 [s];
    }

    part def DamperActuatorNode :> ActuatorNode {
        attribute currentPosition : DamperPosition = 0 [percent];
        attribute targetPosition : DamperPosition;
        attribute motorEnabled : Boolean = false;
        attribute motorTorque : Real = 0;

        action def moveToPosition {
            in target : DamperPosition;
            in out current : DamperPosition;
            in out motorEnabled : Boolean;
            perform {
                assign motorEnabled := true;
                assign current := target;
            }
        }

        action def reportStatus {
            in position : DamperPosition;
            in nodeId : String;
            in out port : LonWorksNetworkPort;
            local status : DamperStatus;
            perform {
                assign status.currentPosition := position;
                assign status.nodeId := nodeId;
                send status to port.damperStatusOut;
            }
        }

        state machine DamperActuatorStateMachine {
            entry;
            state Idle;
            state ReceivingCommand;
            state Moving;
            state Reporting;

            transition from entry to Idle;

            transition from Idle to ReceivingCommand
                accept DamperCommand;

            transition from ReceivingCommand to Moving
                when true;

            transition from Moving to Reporting
                when currentPosition == targetPosition;

            transition from Reporting to Idle
                when true;
        }
    }

    part def FanActuatorNode :> ActuatorNode {
        attribute currentSpeed : FanSpeed = 0 [rpm];
        attribute targetSpeed : FanSpeed;
        attribute maxSpeed : FanSpeed = 2000 [rpm];
        attribute minSpeed : FanSpeed = 0 [rpm];
        attribute motorEnabled : Boolean = false;

        action def setSpeed {
            in target : FanSpeed;
            in out current : FanSpeed;
            in out motorEnabled : Boolean;
            perform {
                assign motorEnabled := true;
                assign current := target;
            }
        }

        action def reportStatus {
            in speed : FanSpeed;
            in nodeId : String;
            in out port : LonWorksNetworkPort;
            local status : FanStatus;
            perform {
                assign status.currentSpeed := speed;
                assign status.nodeId := nodeId;
                send status to port.fanStatusOut;
            }
        }

        state machine FanActuatorStateMachine {
            entry;
            state Idle;
            state ReceivingCommand;
            state AdjustingSpeed;
            state Reporting;

            transition from entry to Idle;

            transition from Idle to ReceivingCommand
                accept FanCommand;

            transition from ReceivingCommand to AdjustingSpeed
                when true;

            transition from AdjustingSpeed to Reporting
                when currentSpeed == targetSpeed;

            transition from Reporting to Idle
                when true;
        }
    }

    // ===== Network Infrastructure =====
    part def TwistedPairNetwork {
        attribute cableType : String = "Twisted Pair";
        attribute protocol : String = "LonWorks";
        attribute baudRate : BaudRate = 78000 [bps];
        attribute maxNodes : Integer = 64;
        attribute terminationResistance : Real = 100;

        port networkInterface : LonWorksNetworkPort;

        action def routeMessage {
            in message : Anything;
            in sourcePort : LonWorksNetworkPort;
            in destPorts : LonWorksNetworkPort[*];
            perform {
                // Peer-to-peer routing over twisted pair
            }
        }
    }

    // ===== System Assembly =====
    part def BuildingAutomationSystem {
        part network : TwistedPairNetwork;

        part tempSensors : TemperatureSensorNode[4] {
            // Zone 1-4 temperature sensors
        }

        part humiditySensors : HumiditySensorNode[4] {
            // Zone 1-4 humidity sensors
        }

        part controllers : HVACControllerNode[2] {
            // Zone controllers
        }

        part damperActuators : DamperActuatorNode[4] {
            // One damper per zone
        }

        part fanActuators : FanActuatorNode[2] {
            // One fan per controller zone
        }

        connection tempSensorToNetwork connect tempSensors.networkPort.tempReadingsOut
            to network.networkInterface.tempReadings;

        connection humiditySensorToNetwork connect humiditySensors.networkPort.humidityReadingsOut
            to network.networkInterface.humidityReadings;

        connection controllerTempFromNetwork connect network.networkInterface.tempReadingsOut
            to controllers.networkPort.tempReadings;

        connection controllerHumidityFromNetwork connect network.networkInterface.humidityReadingsOut
            to controllers.networkPort.humidityReadings;

        connection controllerDamperToNetwork connect controllers.networkPort.damperCommands
            to network.networkInterface.damperCommands;

        connection controllerFanToNetwork connect controllers.networkPort.fanCommands
            to network.networkInterface.fanCommands;

        connection damperToNetwork connect damperActuators.networkPort.damperStatusOut
            to network.networkInterface.damperStatuses;

        connection fanToNetwork connect fanActuators.networkPort.fanStatusOut
            to network.networkInterface.fanStatuses;

        connection damperStatusToController connect network.networkInterface.damperStatuses
            to controllers.networkPort.damperStatuses;

        connection fanStatusToController connect network.networkInterface.fanStatuses
            to controllers.networkPort.fanStatuses;

        connection damperCommandFromNetwork connect network.networkInterface.damperCommands
            to damperActuators.networkPort.damperCommands;

        connection fanCommandFromNetwork connect network.networkInterface.fanCommands
            to fanActuators.networkPort.fanCommands;
    }

    // ===== Requirements =====
    requirement def EnvironmentalControlRequirement {
        subject system : BuildingAutomationSystem;
        attribute targetTemperature : Temperature = 22 [degC];
        attribute targetHumidity : Humidity = 50 [percentRH];
        attribute tempTolerance : Temperature = 2 [degC];
        attribute humidityTolerance : Humidity = 10 [percentRH];

        require system shall maintain indoor temperature within tempTolerance of targetTemperature;
        require system shall maintain indoor humidity within humidityTolerance of targetHumidity;
    }

    requirement def PeerToPeerCommunicationRequirement {
        subject system : BuildingAutomationSystem;
        require system shall use LonWorks protocol over twisted-pair cabling;
        require all nodes shall communicate in peer-to-peer fashion without relying on a single central computer;
        require each node shall have its own processing capability;
    }

    requirement def SensorBroadcastRequirement {
        subject sensors : SensorNode[*];
        attribute maxSamplingInterval : SamplingInterval = 10 [s];
        require sensors shall periodically measure environmental conditions at intervals not exceeding maxSamplingInterval;
        require temperature sensor nodes shall measure temperature;
        require humidity sensor nodes shall measure humidity;
        require sensors shall broadcast readings onto the network;
    }

    requirement def ControllerProcessingRequirement {
        subject controller : HVACControllerNode;
        attribute defaultTempSetpoint : Temperature = 22 [degC];
        attribute defaultHumiditySetpoint : Humidity = 50 [percentRH];

        require controller shall subscribe to temperature readings from temperature sensor nodes;
        require controller shall subscribe to humidity readings from humidity sensor nodes;
        require controller shall compare incoming temperature readings against defaultTempSetpoint;
        require controller shall compare incoming humidity readings against defaultHumiditySetpoint;
        require controller shall use an internal control algorithm to determine necessary adjustments;
        require controller shall send damper command messages to damper actuator nodes;
        require controller shall send fan command messages to fan actuator nodes;
    }

    requirement def DamperActuationRequirement {
        subject damper : DamperActuatorNode;
        require damper shall control a motor to open or close an air damper in the ductwork;
        require damper shall regulate airflow based on received damper position commands;
        require damper shall accept commands specifying position as a percentage;
        require damper shall report its current position status back to the controller;
    }

    requirement def FanActuationRequirement {
        subject fan : FanActuatorNode;
        require fan shall control the speed of a ventilation fan;
        require fan shall accept commands specifying speed in RPM;
        require fan shall report its current speed status back to the controller;
    }

    requirement def FeedbackLoopRequirement {
        subject system : BuildingAutomationSystem;
        require system shall operate as a continuous feedback loop;
        require sensor nodes shall report current environmental conditions to the controller;
        require the controller shall process sensor data and calculate necessary responses;
        require the controller shall send command messages to appropriate actuator nodes;
        require actuator nodes shall execute commands and report status back to the controller;
        require the system shall maintain a stable and comfortable indoor environment;
    }

    requirement def NetworkReliabilityRequirement {
        subject network : TwistedPairNetwork;
        require network shall support peer-to-peer communication between all nodes;
        require network shall operate over twisted-pair cabling;
        require network shall route messages between sensor nodes, controller nodes, and actuator nodes;
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy EnvironmentalControlRequirement by BuildingAutomationSystem;
    satisfaction satisfy PeerToPeerCommunicationRequirement by BuildingAutomationSystem;
    satisfaction satisfy SensorBroadcastRequirement by SensorNode;
    satisfaction satisfy ControllerProcessingRequirement by HVACControllerNode;
    satisfaction satisfy DamperActuationRequirement by DamperActuatorNode;
    satisfaction satisfy FanActuationRequirement by FanActuatorNode;
    satisfaction satisfy FeedbackLoopRequirement by BuildingAutomationSystem;
    satisfaction satisfy NetworkReliabilityRequirement by TwistedPairNetwork;

    // ===== Time Tick Signal for Periodic Sampling =====
    item def TimeTick {
        attribute interval : SamplingInterval;
    }
}
