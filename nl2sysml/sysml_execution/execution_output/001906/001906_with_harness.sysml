package 'Astronaut EVA System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenConcentration :> Real;
    attribute def CO2Concentration :> Real;
    attribute def HeartRateValue :> Real;
    attribute def SuitPressureValue :> PressureValue;
    attribute def BatteryChargeLevel :> Real;
    attribute def CommandSignal;
    attribute def EmergencySignal;
    attribute def TelemetryData;
    
    enum def EVAStatus {
        prebreathing;
        depressurizing;
        active;
        returning;
        repressurizing;
        complete;
    }
    
    enum def HealthStatus {
        nominal;
        caution;
        warning;
        critical;
    }
    
    item def Oxygen;
    item def CarbonDioxide;
    item def CoolingWater;
    item def ElectricalPower;
    item def VoiceData;
    item def BiometricData;
    
    port def LifeSupportPort {
        in oxygenFlow : Real;
        out co2Exhaust : Real;
        in coolingFlow : Real;
    }
    
    port def PowerPort {
        in powerSupply : PowerValue;
        out powerDemand : PowerValue;
    }
    
    port def DataPort {
        out telemetry : TelemetryData;
        in commands : CommandSignal;
        out emergency : EmergencySignal;
    }
    
    port def BiometricPort {
        out heartRate : HeartRateValue;
        out bodyTemperature : TemperatureValue;
        out respirationRate : Real;
    }
    
    part def Astronaut {
        attribute mass : MassValue;
        attribute oxygenConsumptionRate : Real;
        attribute co2ProductionRate : Real;
        attribute metabolicRate : PowerValue;
        
        port biomonitor : BiometricPort;
        port lifeSupport : LifeSupportPort;
        
        action def PerformEVATask {
            in taskDescription : String;
            in taskDuration : TimeValue;
            out taskCompleted : Boolean;
            out energyExpended : EnergyValue;
        }
        
        action def Breathe {
            in oxygenSupplied : Real;
            out co2Produced : Real;
        }
    }
    
    part def PortableLifeSupportSubsystem {
        attribute oxygenCapacity : VolumeValue;
        attribute currentOxygenLevel : Real;
        attribute batteryCapacity : EnergyValue;
        attribute currentBatteryCharge : Real;
        attribute waterCapacity : VolumeValue;
        attribute currentWaterLevel : Real;
        
        port o2Supply : LifeSupportPort;
        port powerOut : PowerPort;
        
        part oxygenTank {
            attribute tankPressure : PressureValue;
            attribute tankVolume : VolumeValue;
            attribute remainingOxygen : Real;
        }
        
        part co2RemovalSystem {
            attribute scrubberCapacity : MassValue;
            attribute scrubberEfficiency : Real;
            attribute currentLoad : Real;
        }
        
        part waterCoolingSystem {
            attribute flowRate : Real;
            attribute inletTemperature : TemperatureValue;
            attribute outletTemperature : TemperatureValue;
        }
        
        part primaryBattery {
            attribute voltage : Real;
            attribute capacity : EnergyValue;
            attribute chargeLevel : Real;
        }
        
        part ventilationFan {
            attribute fanSpeed : Real;
            attribute powerConsumption : PowerValue;
        }
        
        action def SupplyOxygen {
            in demand : Real;
            out supplied : Real;
            out tankPressure : PressureValue;
        }
        
        action def RemoveCO2 {
            in co2Input : Real;
            out co2Removed : Real;
            out scrubberStatus : Real;
        }
        
        action def ProvideCooling {
            in heatLoad : PowerValue;
            out coolingProvided : PowerValue;
            out waterTemp : TemperatureValue;
        }
    }
    
    part def ExtravehicularMobilityUnit {
        attribute suitPressure : PressureValue;
        attribute suitTemperature : TemperatureValue;
        attribute structuralIntegrity : Real;
        
        port crewInterface : LifeSupportPort;
        port powerInterface : PowerPort;
        port commInterface : DataPort;
        
        part helmet {
            attribute visorTransmittance : Real;
            attribute microphoneSensitivity : Real;
        }
        
        part torso {
            attribute hardUpperTorso : Boolean;
            attribute bearingAssemblies : Integer;
        }
        
        part gloves {
            attribute dexterityRating : Real;
            attribute thermalProtection : Real;
        }
        
        part lowerTorso {
            attribute jointMobility : Real;
        }
        
        part boots {
            attribute thermalInsulation : Real;
            attribute treadPattern : String;
        }
        
        state suitOperationalState {
            entry;
            state Donning;
            state PressureCheck;
            state Operational;
            state Safing;
            state Doffing;
            exit;
            
            transition entry to Donning;
            transition PressureCheck to Operational;
            transition Operational to Safing;
            transition Safing to Doffing;
            transition Doffing to exit;
        }
    }
    
    part def HealthMonitoringSystem {
        attribute heartRateThreshold : HeartRateValue;
        attribute tempThresholdLow : TemperatureValue;
        attribute tempThresholdHigh : TemperatureValue;
        attribute respirationThreshold : Real;
        
        port bioInput : BiometricPort;
        port alertOutput : DataPort;
        
        action def MonitorVitals {
            in heartRate : HeartRateValue;
            in bodyTemp : TemperatureValue;
            in respRate : Real;
            out healthStatus : HealthStatus;
            out alertRequired : Boolean;
        }
        
        action def AssessPhysiologicalState {
            in vitalSigns : Real[*];
            out workloadEstimate : Real;
            out fatigueLevel : Real;
        }
    }
    
    part def CommunicationSubsystem {
        attribute transmitPower : PowerValue;
        attribute receiveFrequency : Real;
        attribute transmitFrequency : Real;
        attribute signalStrength : Real;
        
        port dataLink : DataPort;
        port powerIn : PowerPort;
        
        action def TransmitTelemetry {
            in telemetryPacket : TelemetryData;
            out transmitSuccess : Boolean;
        }
        
        action def ReceiveCommands {
            out commandReceived : CommandSignal;
            out commandValid : Boolean;
        }
        
        action def SendEmergencyAlert {
            in alertType : String;
            in severity : HealthStatus;
            out alertSent : Boolean;
        }
    }
    
    part def Spacecraft {
        attribute airlockPressure : PressureValue;
        attribute airlockVolume : VolumeValue;
        
        port umbilicalConnection;
        port communicationRelay : DataPort;
        port powerSupply : PowerPort;
        
        action def DepressurizeAirlock {
            in targetPressure : PressureValue;
            in depressRate : PressureValue;
            out currentPressure : PressureValue;
            out depressComplete : Boolean;
        }
        
        action def RepressurizeAirlock {
            in targetPressure : PressureValue;
            in repressRate : PressureValue;
            out currentPressure : PressureValue;
            out repressComplete : Boolean;
        }
    }
    
    action def MonitorLifeSupport {
        out o2Level : OxygenConcentration;
        out co2Level : CO2Concentration;
        out suitPressure : SuitPressureValue;
        out batteryCharge : BatteryChargeLevel;
    }
    
    action def RegulateEnvironment {
        in o2Level : OxygenConcentration;
        in co2Level : CO2Concentration;
        in suitPressure : SuitPressureValue;
        in metabolicLoad : PowerValue;
        out o2FlowRate : Real;
        out co2RemovalRate : Real;
        out coolingRate : PowerValue;
    }
    
    action def HandleEmergency {
        in emergencyType : String;
        in healthStatus : HealthStatus;
        in resourceLevels : Real[*];
        out abortEVA : Boolean;
        out emergencyProcedure : String;
    }
    
    action def ConductExtravehicularActivity {
        doc /* Primary EVA operational sequence managing all phases of extravehicular operations. */
        
        first start;
        then merge monitoringLoop;
        
        action prebreathe {
            doc /* Astronaut breathes pure oxygen to eliminate nitrogen from bloodstream. */
            accept startPrebreathe : CommandSignal;
        }
        then action depressurize {
            doc /* Airlock pressure reduced to vacuum conditions. */
        }
        then action egressAirlock {
            doc /* Astronaut exits spacecraft through airlock. */
            accept egressCommand : CommandSignal;
        }
        then monitoringLoop;
        
        action monitoringLoop {
            action monitor : MonitorLifeSupport {
                out o2Level;
                out co2Level;
                out suitPressure;
                out batteryCharge;
            }
            
            then action checkVitals : HealthMonitoringSystem::MonitorVitals {
                in heartRate;
                in bodyTemp;
                in respRate;
                out healthStatus;
                out alertRequired;
            }
            
            then decide;
                if checkVitals.alertRequired then emergency;
                else performWork;
            
            action regulate : RegulateEnvironment {
                in o2Level = monitor.o2Level;
                in co2Level = monitor.co2Level;
                in suitPressure = monitor.suitPressure;
                in metabolicLoad;
                out o2FlowRate;
                out co2RemovalRate;
                out coolingRate;
            }
            then monitoringLoop;
            
            action performWork : Astronaut::PerformEVATask {
                in taskDescription;
                in taskDuration;
                out taskCompleted;
                out energyExpended;
            }
            then monitoringLoop;
            
            action emergency : HandleEmergency {
                in emergencyType;
                in healthStatus = checkVitals.healthStatus;
                in resourceLevels;
                out abortEVA;
                out emergencyProcedure;
            }
            then returnToAirlock;
        }
        
        action returnToAirlock {
            doc /* Astronaut returns to spacecraft airlock. */
            accept ingressCommand : CommandSignal;
        }
        then action repressurize {
            doc /* Airlock pressure restored to cabin pressure. */
        }
        then action doffSuit {
            doc /* Astronaut removes EMU and completes post-EVA procedures. */
            accept doffCommand : CommandSignal;
        }
        then done;
    }
    
    part evaSystem {
        doc /* 
        The EVA System enables an astronaut to safely perform work outside a spacecraft in the vacuum of space.
        Its primary function is to provide a self-contained, mobile life support environment that maintains 
        breathable atmosphere, thermal regulation, radiation protection, and communication capabilities, 
        allowing the astronaut to conduct maintenance, assembly, scientific research, and emergency repairs 
        during extravehicular activities lasting up to 8 hours.
        */
        
        part crewmember : Astronaut {
            :>> mass = 80.0[kg];
            :>> oxygenConsumptionRate = 0.84;
            :>> co2ProductionRate = 1.0;
            :>> metabolicRate = 400.0[W];
        }
        
        part emu : ExtravehicularMobilityUnit {
            :>> suitPressure = 29.6[kPa];
            :>> suitTemperature = 294.0[K];
            :>> structuralIntegrity = 1.0;
        }
        
        part plss : PortableLifeSupportSubsystem {
            :>> oxygenCapacity = 1.2[m^3];
            :>> currentOxygenLevel = 100.0;
            :>> batteryCapacity = 1800000.0[J];
            :>> currentBatteryCharge = 100.0;
            :>> waterCapacity = 0.0038[m^3];
            :>> currentWaterLevel = 100.0;
        }
        
        part healthMonitor : HealthMonitoringSystem {
            :>> heartRateThreshold = 180.0;
            :>> tempThresholdLow = 309.0[K];
            :>> tempThresholdHigh = 311.5[K];
            :>> respirationThreshold = 30.0;
        }
        
        part commSystem : CommunicationSubsystem {
            :>> transmitPower = 5.0[W];
            :>> receiveFrequency = 2250.0;
            :>> transmitFrequency = 2287.5;
            :>> signalStrength = 0.85;
        }
        
        part vehicle : Spacecraft {
            :>> airlockPressure = 101.3[kPa];
            :>> airlockVolume = 5.5[m^3];
        }
        
        connect crewmember.lifeSupport to emu.crewInterface;
        connect crewmember.biomonitor to healthMonitor.bioInput;
        connect emu.powerInterface to plss.powerOut;
        connect emu.crewInterface to plss.o2Supply;
        connect emu.commInterface to commSystem.dataLink;
        connect commSystem.dataLink to vehicle.communicationRelay;
        connect healthMonitor.alertOutput to commSystem.dataLink;
        
        perform action evaOperation[*] ordered references ConductExtravehicularActivity;
        
        part plss.oxygenTank {
            perform evaOperation.monitoringLoop.regulate;
        }
        
        part plss.co2RemovalSystem {
            perform evaOperation.monitoringLoop.regulate;
        }
        
        part healthMonitor {
            perform evaOperation.monitoringLoop.checkVitals;
        }
    }
    
    requirement <'EVA-001'> oxygenSupplyRequirement {
        doc /* The PLSS shall provide oxygen at a concentration of 100% with flow rate sufficient 
             to maintain suit pressure between 4.0 and 4.5 psi for minimum 8 hours of EVA. */
        
        subject evaSystem.plss;
        
        require constraint {
            evaSystem.plss.currentOxygenLevel >= 0.0 and
            evaSystem.emu.suitPressure >= 27.6[kPa] and
            evaSystem.emu.suitPressure <= 31.0[kPa]
        }
    }
    
    requirement <'EVA-002'> co2RemovalRequirement {
        doc /* The PLSS shall maintain CO2 partial pressure below 7.6 mmHg (1.0 kPa) 
             throughout the duration of EVA operations. */
        
        subject evaSystem.plss.co2RemovalSystem;
        
        require constraint {
            evaSystem.plss.co2RemovalSystem.currentLoad < 1.0
        }
    }
    
    requirement <'EVA-003'> thermalControlRequirement {
        doc /* The PLSS water cooling system shall maintain astronaut core body temperature 
             between 36.5C and 37.5C under metabolic loads up to 600W. */
        
        subject evaSystem.plss.waterCoolingSystem;
        
        require constraint {
            evaSystem.plss.waterCoolingSystem.inletTemperature >= 277.0[K] and
            evaSystem.plss.waterCoolingSystem.outletTemperature <= 291.0[K]
        }
    }
    
    requirement <'EVA-004'> powerSupplyRequirement {
        doc /* The PLSS primary battery shall provide minimum 500 Wh capacity with voltage 
             regulation maintaining 15-17 VDC output for 8 hour EVA duration. */
        
        subject evaSystem.plss.primaryBattery;
        
        require constraint {
            evaSystem.plss.primaryBattery.chargeLevel >= 0.0 and
            evaSystem.plss.primaryBattery.voltage >= 15.0 and
            evaSystem.plss.primaryBattery.voltage <= 17.0
        }
    }
    
    requirement <'EVA-005'> vitalSignsMonitoringRequirement {
        doc /* The health monitoring system shall continuously track heart rate, body temperature, 
             and respiration rate with real-time telemetry to mission control and automated alerts 
             for out-of-range conditions. */
        
        subject evaSystem.healthMonitor;
        
        assume constraint {
            evaSystem.healthMonitor.heartRateThreshold > 0.0
        }
    }
    
    requirement <'EVA-006'> communicationRequirement {
        doc /* The communication subsystem shall provide continuous two-way voice and data link 
             with spacecraft and ground control with minimum 95% reliability. */
        
        subject evaSystem.commSystem;
        
        require constraint {
            evaSystem.commSystem.signalStrength >= 0.80
        }
    }
    
    requirement <'EVA-007'> suitIntegrityRequirement {
        doc /* The EMU shall maintain structural integrity and pressure seal with leak rate 
             not exceeding 100 sccm (standard cubic centimeters per minute) at operating pressure. */
        
        subject evaSystem.emu;
        
        require constraint {
            evaSystem.emu.structuralIntegrity >= 0.95
        }
    }
    
    requirement <'EVA-MISSION'> missionSuccessRequirement {
        doc /* The EVA System shall enable safe and productive extravehicular operations 
             for mission-critical tasks while ensuring astronaut safety and health. */
        
        subject evaSystem;
        
        assume constraint {
            evaSystem.plss.currentBatteryCharge > 20.0 and
            evaSystem.plss.currentOxygenLevel > 25.0
        }
        
        require oxygenSupplyRequirement;
        require co2RemovalRequirement;
        require thermalControlRequirement;
        require powerSupplyRequirement;
        require vitalSignsMonitoringRequirement;
        require communicationRequirement;
        require suitIntegrityRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Astronaut EVA System'::*;
}
