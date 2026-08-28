package GreenPeakMeshNetwork {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    value type ElectricPotentialValue :> Real { :> unit = V; }
    value type ElectricChargeValue :> Real { :> unit = Ah; }
    value type EnergyValue :> Real { :> unit = J; }
    value type TemperatureValue :> Real { :> unit = degC; }
    value type HumidityValue :> Real { :> unit = 'one'; }
    value type DurationValue :> Real { :> unit = s; }
    value type FrequencyValue :> Real { :> unit = Hz; }
    value type MassValue :> Real { :> unit = kg; }
    value type PowerValue :> Real { :> unit = W; }
    value type DataRateValue :> Real { :> unit = 'bit/s'; }
    value type DistanceValue :> Real { :> unit = m; }
    value type IntegerAddress :> Integer;
    
    // ===== Item Definitions =====
    item def SensorSample {
        attribute nodeAddress : IntegerAddress;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute batteryLevel : ElectricPotentialValue;
        attribute timestamp : Integer;
    }
    
    item def DataFrame {
        attribute sourceAddress : IntegerAddress;
        attribute destinationAddress : IntegerAddress;
        attribute payload : SensorSample;
        attribute sequenceNumber : Integer;
        attribute rssi : Real;
    }
    
    item def Beacon {
        attribute panId : IntegerAddress;
        attribute coordinatorAddress : IntegerAddress;
        attribute channel : Integer;
    }
    
    item def NetworkJoinRequest {
        attribute nodeAddress : IntegerAddress;
        attribute capabilities : String;
    }
    
    item def NetworkJoinResponse {
        attribute assignedAddress : IntegerAddress;
        attribute role : String;
        attribute accepted : Boolean;
    }
    
    item def Acknowledgement {
        attribute sequenceNumber : Integer;
        attribute success : Boolean;
    }
    
    // ===== Requirements =====
    requirement def UltraLowPowerRequirement {
        doc /* The system shall operate for multiple years on a single battery pack. */
        constraint { batteryLifeYears >= 3.0 }
        attribute batteryLifeYears : Real [1] = 3.0;
    }
    
    requirement def MeshNetworkingRequirement {
        doc /* The system shall form a self-healing mesh network capable of multi-hop routing. */
        constraint { maxHops >= 1 }
        constraint { selfHealing == true }
        attribute maxHops : Integer [1] = 8;
        attribute selfHealing : Boolean [1] = true;
    }
    
    requirement def EnvironmentalMonitoringRequirement {
        doc /* Each node shall measure ambient temperature and humidity, and monitor its battery level. */
        constraint { temperatureAccuracyDegC <= 1.0 }
        constraint { humidityAccuracyPct <= 5.0 }
        attribute temperatureAccuracyDegC : Real [1] = 0.5;
        attribute humidityAccuracyPct : Real [1] = 3.0;
    }
    
    requirement def IEEE802154ComplianceRequirement {
        doc /* The RF transceiver shall communicate using the IEEE 802.15.4 standard. */
        constraint { operatingFrequencyHz >= 2.4e9 }
        constraint { operatingFrequencyHz <= 2.5e9 }
        attribute operatingFrequencyHz : Real [1] = 2.45e9;
    }
    
    // ===== Battery Pack =====
    part def BatteryPack {
        attribute nominalVoltage : ElectricPotentialValue [1] := 3.0 [V];
        attribute capacity : ElectricChargeValue [1] := 2.0 [Ah];
        attribute remainingCharge : ElectricChargeValue [1] := 2.0 [Ah];
        attribute mass : MassValue [1] := 0.030 [kg];
        
        port energyOut : BatteryPowerOut;
        port telemetryOut : BatteryTelemetry;
        
        action def deliverPower {
            out power : PowerValue;
        }
    }
    
    port def BatteryPowerOut {
        out power : PowerValue;
        in enable : Boolean;
    }
    
    port def BatteryTelemetry {
        out voltage : ElectricPotentialValue;
        out remainingCapacity : ElectricChargeValue;
    }
    
    // ===== Environmental Sensor =====
    part def EnvironmentalSensor {
        attribute temperatureAccuracy : TemperatureValue [1] := 0.5 [degC];
        attribute humidityAccuracy : HumidityValue [1] := 0.03 ['one'];
        attribute sensingPower : PowerValue [1] := 0.001 [W];
        attribute measurementDuration : DurationValue [1] := 0.1 [s];
        
        port powerIn : BatteryPowerIn;
        port i2cBus : I2CBus;
        
        action def takeReading {
            in enable : Boolean;
            out sample : SensorSample;
        }
        
        action def readBatteryLevel {
            out voltage : ElectricPotentialValue;
        }
    }
    
    port def BatteryPowerIn {
        in power : PowerValue;
        out enable : Boolean;
    }
    
    port def I2CBus {
        in command : String;
        out sample : SensorSample;
    }
    
    // ===== RF Transceiver =====
    part def RFTransceiver {
        attribute standard : String [1] := "IEEE 802.15.4";
        attribute operatingFrequency : FrequencyValue [1] := 2.45e9 [Hz];
        attribute dataRate : DataRateValue [1] := 250000 ['bit/s'];
        attribute txPower : PowerValue [1] := 0.001 [W];
        attribute range : DistanceValue [1] := 100.0 [m];
        attribute rxCurrent : PowerValue [1] := 0.020 [W];
        attribute txCurrent : PowerValue [1] := 0.025 [W];
        attribute sleepCurrent : PowerValue [1] := 0.000001 [W];
        
        port powerIn : BatteryPowerIn;
        port spiBus : SPIBus;
        port antenna : RFPort;
        
        action def transmit {
            in frame : DataFrame;
        }
        
        action def receive {
            out frame : DataFrame;
        }
        
        action def sleepMode {
            in enable : Boolean;
        }
    }
    
    port def SPIBus {
        in command : String;
        in frame : DataFrame;
        out frame : DataFrame;
        out rssi : Real;
    }
    
    port def RFPort {
        out frame : DataFrame;
        in frame : DataFrame;
    }
    
    // ===== Microcontroller =====
    part def Microcontroller {
        attribute clockFrequency : FrequencyValue [1] := 8e6 [Hz];
        attribute activePower : PowerValue [1] := 0.005 [W];
        attribute sleepPower : PowerValue [1] := 0.00001 [W];
        attribute flashMemory : Integer [1] := 131072;
        attribute ram : Integer [1] := 16384;
        
        port powerIn : BatteryPowerIn;
        port sensorI2C : I2CBus;
        port rfSPI : SPIBus;
        
        action def manageOperations {
            out frame : DataFrame;
        }
        
        action def processSensorData {
            in sample : SensorSample;
            in nodeAddress : IntegerAddress;
            out frame : DataFrame;
        }
    }
    
    // ===== Node Role Enumerations =====
    enum def NodeRole { coordinator; router; endDevice; }
    
    // ===== Sensor Node =====
    part def SensorNode {
        attribute nodeAddress : IntegerAddress [1] := 0;
        attribute role : NodeRole [1] := NodeRole::endDevice;
        attribute panId : IntegerAddress [1] := 0;
        attribute sleepDuration : DurationValue [1] := 60.0 [s];
        attribute wakeDuration : DurationValue [1] := 0.5 [s];
        attribute listenDuration : DurationValue [1] := 0.1 [s];
        attribute networkJoined : Boolean [1] := false;
        
        part battery : BatteryPack {
            redefines nominalVoltage := 3.0 [V];
            redefines capacity := 2.0 [Ah];
        }
        
        part sensor : EnvironmentalSensor;
        part mcu : Microcontroller;
        part radio : RFTransceiver;
        
        connect battery.energyOut to sensor.powerIn;
        connect battery.energyOut to mcu.powerIn;
        connect battery.energyOut to radio.powerIn;
        connect battery.telemetryOut to mcu.sensorI2C;
        connect sensor.i2cBus to mcu.sensorI2C;
        connect mcu.rfSPI to radio.spiBus;
        connect radio.antenna to rfAir;
        
        port rfAir : RFPort;
        
        state powerCycleState {
            entry {
                /* Initialize node and enter sleep to conserve energy */
            }
            
            state sleeping {
                entry {
                    /* Deep sleep mode - only RTC running */
                }
            }
            
            state waking {
                entry {
                    /* Power on radio and sensor subsystems */
                }
            }
            
            state sensing {
                entry {
                    /* Take reading from environmental sensor and battery */
                }
            }
            
            state packaging {
                entry {
                    /* Build DataFrame with address and payload */
                }
            }
            
            state transmitting {
                entry {
                    /* Send frame over RF */
                }
            }
            
            state listening {
                entry {
                    /* Listen briefly for incoming messages */
                }
            }
            
            transition idle from sleeping to waking 
                when (timer >= sleepDuration);
            transition sense from waking to sensing 
                when (true);
            transition pack from sensing to packaging 
                when (true);
            transition send from packaging to transmitting 
                when (true);
            transition listen from transmitting to listening 
                when (true);
            transition rest from listening to sleeping 
                when (timer >= listenDuration);
        }
        
        action def nodeCycle {
            in nodeAddr : IntegerAddress;
            out frame : DataFrame;
            
            /* Wake up */
            action wakeUp;
            /* Take sensor reading */
            action takeReading out sample : SensorSample;
            /* Read battery level */
            action readBattery out batteryVoltage : ElectricPotentialValue;
            /* Package data */
            action buildFrame in sample in nodeAddr out frame;
            /* Transmit */
            action transmit in frame;
            /* Listen */
            action listen;
            /* Return to sleep */
            action sleep;
        }
        
        requirement ultraLowPower : UltraLowPowerRequirement;
        requirement envMonitoring : EnvironmentalMonitoringRequirement;
    }
    
    // ===== Coordinator Node =====
    part def CoordinatorNode :> SensorNode {
        redefines role := NodeRole::coordinator;
        attribute managedPANId : IntegerAddress [1] := 0x1234;
        attribute beaconInterval : DurationValue [1] := 15.0 [s];
        
        action def establishNetwork {
            out beacon : Beacon;
        }
        
        action def admitNode {
            in request : NetworkJoinRequest;
            out response : NetworkJoinResponse;
        }
        
        state coordinatorOperation {
            state initializing;
            state broadcasting;
            state admitting;
            state relaying;
            
            transition init from initializing to broadcasting when (true);
            transition beacon from broadcasting to admitting when (timer >= beaconInterval);
            transition admit from admitting to broadcasting when (true);
        }
    }
    
    // ===== Router Node =====
    part def RouterNode :> SensorNode {
        redefines role := NodeRole::router;
        attribute routingTable : String [0..*];
        attribute maxRelayedHops : Integer [1] := 8;
        attribute relayDutyCycle : DurationValue [1] := 5.0 [s];
        
        action def relayMessage {
            in frame : DataFrame;
            out forwarded : DataFrame;
        }
        
        action def discoverRoutes {
            /* Discover available neighbors and build routing table */
        }
        
        state routerOperation {
            state idle;
            state receiving;
            state forwarding;
            state sensing;
            
            transition wake from idle to sensing when (timer >= sleepDuration);
            transition relay from sensing to receiving when (true);
            transition forward from receiving to forwarding when (frameReceived);
            transition done from forwarding to idle when (true);
        }
    }
    
    // ===== End Device Node =====
    part def EndDeviceNode :> SensorNode {
        redefines role := NodeRole::endDevice;
        attribute parentAddress : IntegerAddress [1];
        attribute allowRelay : Boolean [1] := false;
    }
    
    // ===== Mesh Network =====
    part def MeshNetwork {
        attribute panId : IntegerAddress [1] := 0x1234;
        attribute channel : Integer [1] := 15;
        attribute coverageRadius : DistanceValue [1] := 1000.0 [m];
        attribute selfHealing : Boolean [1] := true;
        attribute maximumHops : Integer [1] := 8;
        
        part coordinator : CoordinatorNode;
        part routers : RouterNode [0..*];
        part endDevices : EndDeviceNode [0..*];
        
        connect coordinator.rfAir to rfMedium;
        connect routers.rfAir to rfMedium;
        connect endDevices.rfAir to rfMedium;
        
        port rfMedium : RFPort;
        
        action def routeMessage {
            in source : IntegerAddress;
            in destination : IntegerAddress;
            in payload : DataFrame;
            out delivered : DataFrame;
            
            action discoverPath;
            action hop1;
            action hop2;
            action hop3;
        }
        
        action def selfHeal {
            /* Detect failed nodes and recompute routes */
            action detectFailure;
            action rebuildRoutingTable;
        }
        
        state networkOperation {
            state forming;
            state operational;
            state healing;
            
            transition form from forming to operational when (coordinatorActive);
            transition detect from operational to healing when (nodeFailure);
            transition heal from healing to operational when (routesRebuilt);
        }
        
        requirement meshReq : MeshNetworkingRequirement;
        requirement ieeeReq : IEEE802154ComplianceRequirement;
    }
    
    // ===== GreenPeak System Top-Level =====
    part def GreenPeakSystem {
        attribute applicationDomain : String [1] := "SmartHome/IoT";
        attribute supportedUseCases : String [0..*] := 
            {"Building Automation", "Environmental Monitoring", "Energy Management"};
        
        part mesh : MeshNetwork {
            part coordinator : CoordinatorNode;
            part routers : RouterNode [3];
            part endDevices : EndDeviceNode [10];
        }
        
        requirement ultraLowPower1 : UltraLowPowerRequirement;
        requirement mesh1 : MeshNetworkingRequirement;
        requirement env1 : EnvironmentalMonitoringRequirement;
        requirement ieee1 : IEEE802154ComplianceRequirement;
    }
    
} // end package GreenPeakMeshNetwork
