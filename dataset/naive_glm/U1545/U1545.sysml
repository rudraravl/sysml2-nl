package EVA_System {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    valueType Pressure specializes Real { unit = "Pa"; }
    valueType Temperature specializes Real { unit = "K"; }
    valueType Volume specializes Real { unit = "m3"; }
    valueType MassFlowRate specializes Real { unit = "kg/s"; }
    valueType VolumetricFlowRate specializes Real { unit = "m3/s"; }
    valueType Power specializes Real { unit = "W"; }
    valueType Energy specializes Real { unit = "J"; }
    valueType Duration specializes Real { unit = "s"; }
    valueType HeartRate specializes Real { unit = "bpm"; }
    valueType DataRate specializes Real { unit = "bps"; }

    // Item Types
    item def Oxygen;
    item def CarbonDioxide;
    item def Water;
    item def ElectricalPower;
    item def TelemetryData;
    item def CommandData;
    item def AlertData;

    // Interfaces / Port Definitions
    interface def OxygenFlow {
        end out : Oxygen;
        end in : Oxygen;
    }
    interface def CO2Flow {
        end out : CarbonDioxide;
        end in : CarbonDioxide;
    }
    interface def WaterFlow {
        end out : Water;
        end in : Water;
    }
    interface def PowerFlow {
        end out : ElectricalPower;
        end in : ElectricalPower;
    }
    interface def TelemetryFlow {
        end out : TelemetryData;
        end in : TelemetryData;
    }
    interface def CommandFlow {
        end out : CommandData;
        end in : CommandData;
    }
    interface def AlertFlow {
        end out : AlertData;
        end in : AlertData;
    }

    // Requirements
    requirement def EVASystemRequirements {
        requirement ProvideLifeSupport {
            doc "The system shall provide a self-contained, mobile life support environment."
        }
        requirement MaintainAtmosphere {
            doc "The EMU shall maintain a pressurized, breathable atmosphere."
            attribute nominalPressure : Pressure = 29600 [Pa];
        }
        requirement ThermalControl {
            doc "The PLSS shall remove excess body heat via a water cooling system."
        }
        requirement HealthMonitoringReq {
            doc "The system shall monitor heart rate, body temperature, and respiration."
        }
        requirement CommunicationReq {
            doc "The system shall provide two-way communication and transmit telemetry and alerts."
        }
        requirement EVADurationReq {
            doc "The system shall support EVA durations of up to eight hours."
            attribute maxDuration : Duration = 28800 [s];
        }
    }

    // Parts Definition

    part def ExtravehicularMobilityUnit {
        requirement ref req : EVASystemRequirements::MaintainAtmosphere;
        
        part helmet : Helmet;
        part hardUpperTorso : HardUpperTorso;
        part lowerTorso : LowerTorso;
        part arms : ArmAssembly;
        part gloves : GloveAssembly;
        part boots : BootAssembly;

        port oxygenIn : OxygenFlow;
        port co2Out : CO2Flow;
        port waterIn : WaterFlow;
        port waterOut : WaterFlow;
        port powerIn : PowerFlow;
        port telemetryOut : TelemetryFlow;
        port commandIn : CommandFlow;
        port alertOut : AlertFlow;

        connect oxygenIn to hardUpperTorso.oxygenIn;
        connect hardUpperTorso.co2Out to co2Out;
        connect waterIn to hardUpperTorso.waterIn;
        connect hardUpperTorso.waterOut to waterOut;
        connect powerIn to hardUpperTorso.powerIn;
        connect hardUpperTorso.telemetryOut to telemetryOut;
        connect commandIn to hardUpperTorso.commandIn;
        connect hardUpperTorso.alertOut to alertOut;
    }

    part def Helmet {
        part visor : ProtectiveVisor;
    }
    part def ProtectiveVisor;
    part def HardUpperTorso {
        port oxygenIn : OxygenFlow;
        port co2Out : CO2Flow;
        port waterIn : WaterFlow;
        port waterOut : WaterFlow;
        port powerIn : PowerFlow;
        port telemetryOut : TelemetryFlow;
        port commandIn : CommandFlow;
        port alertOut : AlertFlow;
    }
    part def LowerTorso;
    part def ArmAssembly;
    part def GloveAssembly;
    part def BootAssembly;

    part def PortableLifeSupportSubsystem {
        requirement ref req : EVASystemRequirements::ProvideLifeSupport;
        requirement ref req : EVASystemRequirements::ThermalControl;

        part oxygenTank : OxygenTank;
        part co2Scrubber : CO2Scrubber;
        part waterCoolingSystem : WaterCoolingSystem;
        part battery : Battery;

        port oxygenOut : OxygenFlow;
        port co2In : CO2Flow;
        port waterOut : WaterFlow;
        port waterIn : WaterFlow;
        port powerOut : PowerFlow;

        connect oxygenTank.oxygenOut to oxygenOut;
        connect co2In to co2Scrubber.co2In;
        connect waterOut to waterCoolingSystem.waterOut;
        connect waterCoolingSystem.waterIn to waterIn;
        connect battery.powerOut to powerOut;
    }

    part def OxygenTank {
        attribute capacity : Volume = 0.005 [m3];
        port oxygenOut : OxygenFlow;
    }
    part def CO2Scrubber {
        port co2In : CO2Flow;
    }
    part def WaterCoolingSystem {
        port waterOut : WaterFlow;
        port waterIn : WaterFlow;
    }
    part def Battery {
        attribute capacity : Energy = 36000000 [J];
        port powerOut : PowerFlow;
    }

    part def HealthMonitoringSystem {
        requirement ref req : EVASystemRequirements::HealthMonitoringReq;

        part biometricSensors : BiometricSensors;
        part alertProcessor : AlertProcessor;

        attribute abortTriggered : Boolean = false;

        port telemetryIn : TelemetryFlow;
        port alertOut : AlertFlow;

        connect biometricSensors.telemetryOut to alertProcessor.telemetryIn;
        connect alertProcessor.alertOut to alertOut;

        state def HealthMonitoringStateMachine {
            entry action { /* initialize */ }
            state Normal {
                entry action { /* vitals within safe limits */ }
            }
            state Caution {
                entry action { /* generate caution alert */ }
            }
            state Warning {
                entry action { /* generate warning alert */ }
            }
            state Critical {
                entry action { 
                    /* generate critical alert, trigger abort */ 
                    abortTriggered = true;
                }
            }
            transition from Normal to Caution when (biometricSensors.heartRate > 150 [bpm]);
            transition from Caution to Warning when (biometricSensors.heartRate > 170 [bpm]);
            transition from Warning to Critical when (biometricSensors.heartRate > 190 [bpm]);
            transition from Caution to Normal when (biometricSensors.heartRate < 140 [bpm]);
            transition from Warning to Caution when (biometricSensors.heartRate < 160 [bpm]);
        }
        
        exhibit state behavior : HealthMonitoringStateMachine;
    }

    part def BiometricSensors {
        attribute heartRate : HeartRate;
        attribute bodyTemp : Temperature;
        attribute respirationRate : Real;
        port telemetryOut : TelemetryFlow;
    }
    part def AlertProcessor {
        port telemetryIn : TelemetryFlow;
        port alertOut : AlertFlow;
    }

    part def CommunicationSubsystem {
        requirement ref req : EVASystemRequirements::CommunicationReq;

        part transceiver : Transceiver;
        part antenna : Antenna;

        port telemetryIn : TelemetryFlow;
        port alertIn : AlertFlow;
        port commandOut : CommandFlow;
        port externalLink : TelemetryFlow;

        connect telemetryIn to transceiver.telemetryIn;
        connect alertIn to transceiver.alertIn;
        connect transceiver.commandOut to commandOut;
        connect transceiver.externalLink to antenna.externalLink;
        connect antenna.externalLink to externalLink;
    }

    part def Transceiver {
        port telemetryIn : TelemetryFlow;
        port alertIn : AlertFlow;
        port commandOut : CommandFlow;
        port externalLink : TelemetryFlow;
    }
    part def Antenna {
        port externalLink : TelemetryFlow;
    }

    part def SpacecraftAirlock {
        attribute internalPressure : Pressure;
        
        state def AirlockOperationStateMachine {
            state Pressurized {
                entry action { internalPressure = 101000 [Pa]; }
            }
            state Depressurizing {
                entry action { internalPressure = internalPressure - 1000 [Pa]; }
            }
            state Vacuum {
                entry action { internalPressure = 0 [Pa]; }
            }
            state Repressurizing {
                entry action { internalPressure = internalPressure + 1000 [Pa]; }
            }
            transition from Pressurized to Depressurizing when (true);
            transition from Depressurizing to Vacuum when (internalPressure == 0 [Pa]);
            transition from Vacuum to Repressurizing when (true);
            transition from Repressurizing to Pressurized when (internalPressure == 101000 [Pa]);
        }

        exhibit state behavior : AirlockOperationStateMachine;
    }

    part def AstronautEVASystem {
        requirement ref req : EVASystemRequirements;
        
        part emu : ExtravehicularMobilityUnit;
        part plss : PortableLifeSupportSubsystem;
        part healthMonitor : HealthMonitoringSystem;
        part comm : CommunicationSubsystem;
        part airlock : SpacecraftAirlock;

        connect plss.oxygenOut to emu.oxygenIn;
        connect emu.co2Out to plss.co2In;
        connect plss.waterOut to emu.waterIn;
        connect emu.waterOut to plss.waterIn;
        connect plss.powerOut to emu.powerIn;
        connect emu.telemetryOut to healthMonitor.telemetryIn;
        connect healthMonitor.alertOut to comm.alertIn;
        connect emu.telemetryOut to comm.telemetryIn;
        connect comm.commandOut to emu.commandIn;

        state def EVAOperationStateMachine {
            state Prebreathe {
                entry action { /* astronaut prebreathes pure oxygen */ }
            }
            state Depressurize {
                entry action { /* airlock depressurizes */ }
            }
            state EVA {
                entry action { /* astronaut exits and works */ }
            }
            state EmergencyAbort {
                entry action { /* return to airlock immediately */ }
            }
            state Repressurize {
                entry action { /* airlock repressurizes */ }
            }
            transition from Prebreathe to Depressurize when (true);
            transition from Depressurize to EVA when (airlock.internalPressure == 0 [Pa]);
            transition from EVA to EmergencyAbort when (healthMonitor.abortTriggered == true);
            transition from EVA to Repressurize when (true);
            transition from EmergencyAbort to Repressurize when (true);
            transition from Repressurize to Prebreathe when (airlock.internalPressure == 101000 [Pa]);
        }

        exhibit state behavior : EVAOperationStateMachine;
    }
}
