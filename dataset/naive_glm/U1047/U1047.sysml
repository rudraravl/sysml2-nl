package SelfPoweredSensorNetwork {

    // ===== Value Types with Units =====

    value def PowerValue :> Real { unit 'mW'; }
    value def EnergyValue :> Real { unit 'mJ'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def TemperatureValue :> Real { unit '°C'; }
    value def FrequencyValue :> Real { unit 'MHz'; }
    value def DistanceValue :> Real { unit 'm'; }
    value def IlluminanceValue :> Real { unit 'lux'; }
    value def TimeValue :> Real { unit 'ms'; }
    value def CurrentValue :> Real { unit 'mA'; }
    value def DataRateValue :> Real { unit 'kbps'; }

    // ===== Item Definitions =====

    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute occupancy : Boolean;
        attribute lightLevel : IlluminanceValue;
        attribute nodeId : String;
        attribute timestamp : String;
    }

    item def RadioTelegram {
        attribute telegramId : String;
        attribute nodeId : String;
        attribute payload : SensorData;
        attribute frequency : FrequencyValue := 868.0;
        attribute rssi : Real;
        attribute checksum : String;
    }

    item def EthernetFrame {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payload : SensorData;
        attribute protocol : String := "TCP/IP";
    }

    item def ControlCommand {
        attribute targetRoomId : String;
        attribute lightingOn : Boolean;
        attribute hvacSetpoint : TemperatureValue;
        attribute priority : Integer;
    }

    item def HarvestedEnergy {
        attribute amount : EnergyValue;
        attribute source : String;
    }

    item def RegulatedPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    // ===== Port Definitions =====

    port def RadioOutPort {
        out telegram : RadioTelegram;
    }

    port def RadioInPort {
        in telegram : RadioTelegram;
    }

    port def EthernetOutPort {
        out frame : EthernetFrame;
    }

    port def EthernetInPort {
        in frame : EthernetFrame;
    }

    port def ControlOutPort {
        out command : ControlCommand;
    }

    port def PowerOutPort {
        out power : RegulatedPower;
    }

    port def EnergyOutPort {
        out energy : HarvestedEnergy;
    }

    // ===== Interfaces =====

    interface def RadioLink {
        end sender : RadioOutPort;
        end receiver : RadioInPort;
    }

    interface def EthernetLink {
        end sender : EthernetOutPort;
        end receiver : EthernetInPort;
    }

    // ===== Requirements =====

    requirement def EnergyAutonomyRequirement {
        doc "The sensor node shall operate entirely without batteries, harvesting ambient energy from solar and piezoelectric sources.";
        attribute minHarvestedEnergy : EnergyValue := 0.5;
        constraint { harvestedEnergy >= minHarvestedEnergy }
    }

    requirement def WirelessTransmissionRequirement {
        doc "The sensor node shall transmit data on 868 MHz with range up to 300 m using ultra-low-power radio.";
        attribute frequency : FrequencyValue := 868.0;
        attribute maxRange : DistanceValue := 300.0;
    }

    requirement def GatewayRequirement {
        doc "The gateway shall receive, validate, and forward radio telegrams to the BMS via Ethernet or Wi-Fi.";
    }

    requirement def BMSControlRequirement {
        doc "The BMS shall analyze sensor data and issue control commands for adaptive energy optimization of lighting and HVAC.";
    }

    requirement def MaintenanceFreeRequirement {
        doc "The system shall be maintenance-free with no battery replacement required over its operational lifetime.";
    }

    requirement def MultiSensingRequirement {
        doc "Each sensor node shall measure temperature, occupancy, and light level and bundle them into a single data payload.";
    }

    // ===== Sensor Node Subcomponents =====

    part def SolarHarvester {
        attribute cellType : String := "Amorphous Silicon";
        attribute minIlluminance : IlluminanceValue := 50.0;
        attribute peakOutputPower : PowerValue := 5.0;
        port energyOut : EnergyOutPort;

        action def harvestSolarEnergy {
            in illuminance : IlluminanceValue;
            out harvested : HarvestedEnergy;
            // Convert indoor light to electrical energy
        }
    }

    part def PiezoelectricHarvester {
        attribute sourceType : String := "Mechanical Motion/Vibration";
        attribute energyPerEvent : EnergyValue := 0.3;
        port energyOut : EnergyOutPort;

        action def harvestPiezoEnergy {
            in motionEvent : Boolean;
            out harvested : HarvestedEnergy;
            // Generate power from mechanical press or vibration
        }
    }

    part def EnergyStorageCapacitor {
        attribute maxCapacity : EnergyValue := 10.0;
        attribute currentCharge : EnergyValue := 0.0;
        attribute minChargeForTransmission : EnergyValue := 5.0;
        attribute minChargeForSensing : EnergyValue := 1.0;

        action def charge {
            in energy : HarvestedEnergy;
            update currentCharge : EnergyValue;
        }

        action def discharge {
            out power : RegulatedPower;
            update currentCharge : EnergyValue;
        }
    }

    part def PowerManagementChip {
        attribute chargeThreshold : EnergyValue := 5.0;
        attribute regulatedVoltage : VoltageValue := 3.3;
        attribute standbyCurrent : CurrentValue := 0.1;
        port powerOut : PowerOutPort;

        action def manageEnergyFlow {
            in capacitorCharge : EnergyValue;
            out enablePower : Boolean;
            if capacitorCharge >= chargeThreshold {
                enablePower = true;
            } else {
                enablePower = false;
            }
        }
    }

    part def MultiSensorUnit {
        attribute temperatureRangeMin : TemperatureValue := 0.0;
        attribute temperatureRangeMax : TemperatureValue := 50.0;
        attribute occupancyDetectionMethod : String := "PIR";
        attribute lightLevelRangeMax : IlluminanceValue := 10000.0;

        action def takeSnapshot {
            out temperature : TemperatureValue;
            out occupancy : Boolean;
            out lightLevel : IlluminanceValue;
        }

        action def assemblePayload {
            in temperature : TemperatureValue;
            in occupancy : Boolean;
            in lightLevel : IlluminanceValue;
            in nodeId : String;
            out payload : SensorData;
        }
    }

    part def EnOceanRadioModule {
        attribute frequency : FrequencyValue := 868.0;
        attribute maxRange : DistanceValue := 300.0;
        attribute modulation : String := "ASK";
        attribute dataRate : DataRateValue := 125.0;
        attribute txDuration : TimeValue := 1.0;
        port radioOut : RadioOutPort;

        action def transmitTelegram {
            in sensorData : SensorData;
            out telegram : RadioTelegram;
        }
    }

    // ===== EnOcean Sensor Node =====

    part def EnOceanSensorNode {
        attribute nodeId : String;
        attribute location : String;
        attribute firmwareVersion : String := "2.1.0";

        port radioOut : RadioOutPort;

        part solarHarvester : SolarHarvester;
        part piezoHarvester : PiezoelectricHarvester;
        part capacitor : EnergyStorageCapacitor;
        part powerManagement : PowerManagementChip;
        part multiSensor : MultiSensorUnit;
        part radioModule : EnOceanRadioModule;

        // Energy flow from harvesters to capacitor
        flow solarHarvester.energyOut.energy to capacitor.charge.energy;
        flow piezoHarvester.energyOut.energy to capacitor.charge.energy;

        // Power flow from capacitor through power management to components
        flow capacitor.discharge.power to powerManagement.powerOut.power;
        flow powerManagement.powerOut.power to multiSensor;
        flow powerManagement.powerOut.power to radioModule;

        // Data flow from sensor to radio module
        flow multiSensor.takeSnapshot to radioModule.transmitTelegram.sensorData;

        // Radio output connection
        connect radioModule.radioOut to radioOut;

        satisfy EnergyAutonomyRequirement;
        satisfy WirelessTransmissionRequirement;
        satisfy MaintenanceFreeRequirement;
        satisfy MultiSensingRequirement;

        state def SensorNodeStateMachine {
            entry action initializeNode;

            state Harvesting {
                entry action startHarvesting;
                do action harvestEnergy {
                    // Solar and piezoelectric harvesters collect ambient energy
                }
            }

            state Charging {
                entry action beginCharging;
                do action chargeCapacitor {
                    // Capacitor accumulates harvested energy
                }
            }

            state Ready {
                entry action checkPowerLevel;
                do action waitForSufficientCharge;
            }

            state Sensing {
                entry action activateSensors;
                do action takeSnapshot {
                    // Multi-sensor unit measures temperature, occupancy, light level
                }
            }

            state Transmitting {
                entry action powerRadioModule;
                do action sendTelegram {
                    // Radio module transmits radio telegram on 868 MHz
                }
            }

            transition from Harvesting to Charging
                when capacitor.currentCharge > 0.0;

            transition from Charging to Ready
                when capacitor.currentCharge >= capacitor.minChargeForTransmission;

            transition from Ready to Sensing
                when powerManagement.manageEnergyFlow.enablePower == true;

            transition from Sensing to Transmitting
                when multiSensor.takeSnapshot.complete;

            transition from Transmitting to Harvesting
                when radioModule.transmitTelegram.complete;
        }

        exhibit SensorNodeStateMachine;
    }

    // ===== EnOcean Gateway =====

    part def EnOceanGateway {
        attribute gatewayId : String;
        attribute ipAddress : String;
        attribute macAddress : String;
        attribute powerSource : String := "Mains";
        attribute networkInterface : String := "Ethernet/Wi-Fi";
        attribute maxNodesSupported : Integer := 500;

        port radioIn : RadioInPort;
        port ethernetOut : EthernetOutPort;

        action def receiveTelegram {
            in telegram : RadioTelegram;
        }

        action def validateTelegram {
            in telegram : RadioTelegram;
            out isValid : Boolean;
            // Verify checksum and telegram structure
        }

        action def extractSensorData {
            in telegram : RadioTelegram;
            out sensorData : SensorData;
            // Parse payload from validated telegram
        }

        action def forwardToBMS {
            in sensorData : SensorData;
            out frame : EthernetFrame;
            // Package sensor data into Ethernet frame
        }

        flow radioIn.telegram to receiveTelegram.telegram;
        flow receiveTelegram.telegram to validateTelegram.telegram;
        flow validateTelegram to extractSensorData;
        flow extractSensorData.sensorData to forwardToBMS.sensorData;
        flow forwardToBMS.frame to ethernetOut.frame;

        satisfy GatewayRequirement;

        state def GatewayStateMachine {
            entry action initializeGateway;

            state Listening {
                entry action activateReceiver;
                do action listenForTelegrams {
                    // Continuously monitor 868 MHz band
                }
            }

            state Processing {
                entry action beginProcessing;
                do action validateAndExtract {
                    // Validate checksum and extract sensor data
                }
            }

            state Forwarding {
                entry action prepareFrame;
                do action sendEthernetFrame {
                    // Forward data to BMS via Ethernet
                }
            }

            transition from Listening to Processing
                when radioIn.telegram.received;

            transition from Processing to Forwarding
                when validateTelegram.isValid == true;

            transition from Processing to Listening
                when validateTelegram.isValid == false;

            transition from Forwarding to Listening
                when forwardToBMS.complete;
        }

        exhibit GatewayStateMachine;
    }

    // ===== Building Management System =====

    part def BuildingManagementSystem {
        attribute bmsId : String;
        attribute controlStrategy : String := "Adaptive Energy Optimization";
        attribute roomsManaged : Integer;
        attribute defaultHvacSetpoint : TemperatureValue := 22.0;
        attribute unoccupiedHvacSetpoint : TemperatureValue := 26.0;

        port ethernetIn : EthernetInPort;
        port controlOut : ControlOutPort;

        action def receiveSensorData {
            in frame : EthernetFrame;
            out sensorData : SensorData;
        }

        action def analyzeData {
            in sensorData : SensorData;
            out analysisResult : SensorData;
            // Evaluate occupancy, temperature, and light level
        }

        action def decideControlAction {
            in sensorData : SensorData;
            out command : ControlCommand;
            // Apply adaptive energy optimization strategy
            if sensorData.occupancy == false && sensorData.lightLevel > 5000.0 {
                command.lightingOn = false;
                command.hvacSetpoint = unoccupiedHvacSetpoint;
            } else {
                command.lightingOn = true;
                command.hvacSetpoint = defaultHvacSetpoint;
            }
        }

        action def executeControl {
            in command : ControlCommand;
            // Dispatch command to building subsystems
        }

        flow ethernetIn.frame to receiveSensorData.frame;
        flow receiveSensorData.sensorData to analyzeData.sensorData;
        flow analyzeData to decideControlAction;
        flow decideControlAction.command to executeControl.command;
        flow decideControlAction.command to controlOut.command;

        satisfy BMSControlRequirement;

        state def BMSStateMachine {
            entry action initializeBMS;

            state Idle {
                entry action enterIdle;
                do action waitForData {
                    // Await incoming sensor data from gateway
                }
            }

            state Analyzing {
                entry action beginAnalysis;
                do action analyzeSensorData {
                    // Analyze temperature, occupancy, and light level
                }
            }

            state Deciding {
                entry action beginDecision;
                do action determineControlAction {
                    // Apply adaptive energy optimization rules
                }
            }

            state Executing {
                entry action beginExecution;
                do action issueControlCommand {
                    // Send lighting and HVAC commands
                }
            }

            transition from Idle to Analyzing
                when ethernetIn.frame.received;

            transition from Analyzing to Deciding
                when analyzeData.complete;

            transition from Deciding to Executing
                when decideControlAction.complete;

            transition from Executing to Idle
                when executeControl.complete;
        }

        exhibit BMSStateMachine;
    }

    // ===== Top-Level System =====

    part def SmartBuildingAutomationSystem {
        attribute systemId : String := "SBAS-001";
        attribute buildingName : String;
        attribute deploymentDate : String;

        part sensorNodes : EnOceanSensorNode[*];
        part gateway : EnOceanGateway;
        part bms : BuildingManagementSystem;

        // Radio links between sensor nodes and gateway
        interface radioLinks : RadioLink[*] connect sensorNodes.radioOut to gateway.radioIn;

        // Ethernet link between gateway and BMS
        interface ethernetLink : EthernetLink connect gateway.ethernetOut to bms.ethernetIn;

        satisfy MaintenanceFreeRequirement;

        action def SystemOperationFlow {
            // Describes end-to-end operational flow
            in environmentalStimulus;
            out controlAction;

            action harvestEnergy {
                out storedEnergy : EnergyValue;
            }

            action senseEnvironment {
                in storedEnergy : EnergyValue;
                out sensorData : SensorData;
            }

            action transmitWirelessly {
                in sensorData : SensorData;
                out telegram : RadioTelegram;
            }

            action receiveAndForward {
                in telegram : RadioTelegram;
                out frame : EthernetFrame;
            }

            action analyzeAndControl {
                in frame : EthernetFrame;
                out command : ControlCommand;
            }

            flow harvestEnergy.storedEnergy to senseEnvironment.storedEnergy;
            flow senseEnvironment.sensorData to transmitWirelessly.sensorData;
            flow transmitWirelessly.telegram to receiveAndForward.telegram;
            flow receiveAndForward.frame to analyzeAndControl.frame;
        }
    }

    // ===== System Instantiation =====

    part buildingSystem : SmartBuildingAutomationSystem {
        attribute buildingName := "Office Tower A";
        attribute deploymentDate := "2025-01-15";

        part sensorNodes {
            part node1 : EnOceanSensorNode {
                attribute nodeId := "SN-001";
                attribute location := "Conference Room A";
            }
            part node2 : EnOceanSensorNode {
                attribute nodeId := "SN-002";
                attribute location := "Office 101";
            }
            part node3 : EnOceanSensorNode {
                attribute nodeId := "SN-003";
                attribute location := "Office 102";
            }
        }

        part gateway : EnOceanGateway {
            attribute gatewayId := "GW-001";
            attribute ipAddress := "192.168.1.100";
            attribute macAddress := "00:1B:44:11:3A:B7";
        }

        part bms : BuildingManagementSystem {
            attribute bmsId := "BMS-001";
            attribute roomsManaged := 3;
        }
    }
}
