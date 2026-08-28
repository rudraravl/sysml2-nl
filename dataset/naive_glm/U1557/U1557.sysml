package ISS_System {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type PowerValue > Real { unit 'kW'; }
    value type EnergyValue > Real { unit 'kWh'; }
    value type TemperatureValue > Real { unit 'K'; }
    value type PressureValue > Real { unit 'kPa'; }
    value type AltitudeValue > Real { unit 'km'; }
    value type VelocityValue > Real { unit 'm/s'; }
    value type AttitudeValue > Real { unit 'deg'; }
    value type MassFlowValue > Real { unit 'kg/s'; }
    value type VolumeValue > Real { unit 'm^3'; }
    value type DataRateValue > Real { unit 'Mbps'; }
    value type ForceValue > Real { unit 'N'; }
    value type AreaValue > Real { unit 'm^2'; }

    // ===== Item Types =====
    item Sunlight;
    item ElectricalPower;
    item Oxygen;
    item CarbonDioxide;
    item Water;
    item WasteHeat;
    item Coolant;
    item Telemetry;
    item Command;
    item ScienceData;

    // ===== Port Definitions =====
    port def SunlightPort {
        in Sunlight;
    }

    port def PowerPort {
        out ElectricalPower;
        attribute power : PowerValue;
    }

    port def AtmospherePort {
        out Oxygen;
        in CarbonDioxide;
        attribute pressure : PressureValue;
    }

    port def WaterPort {
        out Water;
        in Water;
    }

    port def ThermalPort {
        out WasteHeat;
        attribute temperature : TemperatureValue;
    }

    port def CoolantPort {
        out Coolant;
        in Coolant;
        attribute flowRate : MassFlowValue;
    }

    port def DataPort {
        out Telemetry;
        in Command;
        attribute dataRate : DataRateValue;
    }

    port def ScienceDataPort {
        out ScienceData;
        attribute dataRate : DataRateValue;
    }

    port def ThrustCmdPort {
        out thrust : ForceValue;
    }

    port def ThrustPort {
        out thrust : ForceValue;
    }

    // ===== Solar Array =====
    part def SolarArray {
        port sunIn : SunlightPort;
        port powerOut : PowerPort;

        attribute efficiency : Real = 0.30;
        attribute panelArea : AreaValue = 375.0;
        attribute generatedPower : PowerValue;
        attribute panelAngle : AttitudeValue;
        attribute sunAngle : AttitudeValue;

        action def TrackSun {
            in sunAngle : AttitudeValue;
            out panelAngle : AttitudeValue;

            action computeOptimalAngle {
                in sunAngle : AttitudeValue;
                out panelAngle : AttitudeValue;
            }
            then action orientPanel {
                in panelAngle : AttitudeValue;
            }
        }

        perform TrackSun;

        state def SolarArrayState {
            initial Stowed;
            state Deployed;
            state Tracking;
            state Eclipse;

            transition Stowed to Deployed when sunIn->Sunlight;
            transition Deployed to Tracking when sunIn->Sunlight;
            transition Tracking to Eclipse when not sunIn->Sunlight;
            transition Eclipse to Tracking when sunIn->Sunlight;
            transition Tracking to Tracking do TrackSun;
        }

        perform SolarArrayState;
    }

    // ===== Solar Power System =====
    part def SolarPowerSystem {
        port powerOut : PowerPort;
        part arrays : SolarArray[8];

        attribute totalPower : PowerValue;
        attribute sunTrackingActive : Boolean = false;
        attribute nominalPower : PowerValue = 90.0;

        binding arrays.powerOut to powerOut;

        action def AggregatePower {
            in arrayPower : PowerValue[8];
            out totalPower : PowerValue;

            action sumPower {
                in arrayPower : PowerValue[8];
                out totalPower : PowerValue;
            }
        }

        perform AggregatePower;

        state def SolarPowerState {
            initial Inactive;
            state Generating;
            state Degraded;

            transition Inactive to Generating when totalPower > 0;
            transition Generating to Degraded when totalPower < 50.0;
            transition Degraded to Generating when totalPower >= 50.0;
        }

        perform SolarPowerState;
    }

    // ===== ECLSS =====
    part def ECLSS {
        port powerIn : ~PowerPort;
        port atmosphereOut : AtmospherePort;
        port waterOut : WaterPort;
        port waterIn : ~WaterPort;
        port thermalOut : ThermalPort;

        attribute oxygenProductionRate : MassFlowValue = 0.005;
        attribute co2ScrubRate : MassFlowValue = 0.01;
        attribute waterRecycleRate : MassFlowValue = 0.02;
        attribute cabinPressure : PressureValue = 101.3;
        attribute targetPressure : PressureValue = 101.3;

        action def GenerateOxygen {
            in power : ElectricalPower;
            out oxygen : Oxygen;
        }

        action def ScrubCO2 {
            in co2 : CarbonDioxide;
            out scrubbedGas : Oxygen;
        }

        action def RecycleWater {
            in wasteWater : Water;
            out cleanWater : Water;
        }

        perform GenerateOxygen;
        perform ScrubCO2;
        perform RecycleWater;

        state def ECLSSState {
            initial Standby;
            state Active {
                parallel OxygenGeneration {
                    initial Idle1;
                    state Generating1;
                    transition Idle1 to Generating1 when powerIn->ElectricalPower;
                    transition Generating1 to Idle1 when not powerIn->ElectricalPower;
                }
                parallel CO2Scrubbing {
                    initial Idle2;
                    state Scrubbing2;
                    transition Idle2 to Scrubbing2 when powerIn->ElectricalPower;
                    transition Scrubbing2 to Idle2 when not powerIn->ElectricalPower;
                }
                parallel WaterRecycling {
                    initial Idle3;
                    state Recycling3;
                    transition Idle3 to Recycling3 when powerIn->ElectricalPower;
                    transition Recycling3 to Idle3 when not powerIn->ElectricalPower;
                }
            }
            transition Standby to Active when powerIn->ElectricalPower;
            transition Active to Standby when not powerIn->ElectricalPower;
        }

        perform ECLSSState;
    }

    // ===== Thermal Control System =====
    part def ThermalControlSystem {
        port powerIn : ~PowerPort;
        port thermalIn : ~ThermalPort;
        port coolantLoop : CoolantPort;

        attribute radiatorArea : AreaValue = 1500.0;
        attribute coolantFlowRate : MassFlowValue = 0.5;
        attribute internalTemp : TemperatureValue = 293.0;
        attribute targetTemp : TemperatureValue = 293.0;
        attribute maxTemp : TemperatureValue = 303.0;
        attribute minTemp : TemperatureValue = 291.0;

        action def CirculateCoolant {
            in coolantIn : Coolant;
            out coolantOut : Coolant;
        }

        action def DissipateHeat {
            in wasteHeat : WasteHeat;
        }

        perform CirculateCoolant;
        perform DissipateHeat;

        state def ThermalState {
            initial Nominal;
            state Cooling;
            state Overheating;

            transition Nominal to Cooling when internalTemp > targetTemp;
            transition Cooling to Nominal when internalTemp <= targetTemp;
            transition Nominal to Overheating when internalTemp > maxTemp;
            transition Cooling to Overheating when internalTemp > maxTemp;
            transition Overheating to Cooling when internalTemp <= maxTemp and powerIn->ElectricalPower;
        }

        perform ThermalState;
    }

    // ===== GNC =====
    part def GNC {
        port powerIn : ~PowerPort;
        port dataOut : DataPort;
        port thrustCmd : ThrustCmdPort;

        attribute currentAttitude : AttitudeValue = 0.0;
        attribute targetAttitude : AttitudeValue = 0.0;
        attribute currentAltitude : AltitudeValue = 408.0;
        attribute targetAltitude : AltitudeValue = 408.0;
        attribute orbitalVelocity : VelocityValue = 7660.0;
        attribute dragRate : VelocityValue = 0.001;
        attribute attitudeError : AttitudeValue = 0.0;

        action def DetermineAttitude {
            out attitude : AttitudeValue;
        }

        action def DeterminePosition {
            out altitude : AltitudeValue;
            out velocity : VelocityValue;
        }

        action def ComputeReboost {
            in currentAlt : AltitudeValue;
            in targetAlt : AltitudeValue;
            out thrust : ForceValue;
        }

        action def ComputeAttitudeAdjust {
            in currentAtt : AttitudeValue;
            in targetAtt : AttitudeValue;
            out correction : AttitudeValue;
        }

        perform DetermineAttitude;
        perform DeterminePosition;

        state def GNCState {
            initial Idle;
            state Monitoring;
            state AttitudeAdjusting;
            state ReboostPlanning;

            transition Idle to Monitoring when powerIn->ElectricalPower;
            transition Monitoring to AttitudeAdjusting when attitudeError > 5.0;
            transition AttitudeAdjusting to Monitoring when attitudeError <= 1.0;
            transition Monitoring to ReboostPlanning when currentAltitude < targetAltitude - 2.0;
            transition ReboostPlanning to Monitoring when currentAltitude >= targetAltitude;
        }

        perform GNCState;
    }

    // ===== Propulsion Module =====
    part def PropulsionModule {
        port powerIn : ~PowerPort;
        port thrustCmdIn : ~ThrustCmdPort;
        port thrustOut : ThrustPort;

        attribute thrustLevel : ForceValue = 0.0;
        attribute propellantMass : Real = 1000.0;
        attribute maxThrust : ForceValue = 500.0;
        attribute specificImpulse : Real = 300.0;

        action def FireThrusters {
            in commandedThrust : ForceValue;
            out actualThrust : ForceValue;
        }

        perform FireThrusters;

        state def PropulsionState {
            initial Idle;
            state Firing;
            state Depleted;

            transition Idle to Firing when thrustCmdIn->thrust > 0;
            transition Firing to Idle when thrustCmdIn->thrust == 0;
            transition Firing to Depleted when propellantMass <= 0;
        }

        perform PropulsionState;
    }

    // ===== Communications System =====
    part def CommunicationsSystem {
        port powerIn : ~PowerPort;
        port groundLink : DataPort;
        port scienceIn : ~ScienceDataPort;
        port telemetryIn : ~DataPort;

        attribute downlinkRate : DataRateValue = 50.0;
        attribute uplinkRate : DataRateValue = 10.0;
        attribute bufferCapacity : DataRateValue = 100.0;
        attribute linkActive : Boolean = false;

        action def TransmitTelemetry {
            in telemetry : Telemetry;
        }

        action def ReceiveCommands {
            out command : Command;
        }

        action def TransmitScienceData {
            in scienceData : ScienceData;
        }

        perform TransmitTelemetry;
        perform ReceiveCommands;
        perform TransmitScienceData;

        state def CommState {
            initial Offline;
            state Online {
                parallel Downlink {
                    initial IdleD;
                    state Transmitting;
                    transition IdleD to Transmitting when telemetryIn->Telemetry or scienceIn->ScienceData;
                    transition Transmitting to IdleD when not (telemetryIn->Telemetry or scienceIn->ScienceData);
                }
                parallel Uplink {
                    initial IdleU;
                    state Receiving;
                    transition IdleU to Receiving when groundLink->Command;
                    transition Receiving to IdleU when not groundLink->Command;
                }
            }
            transition Offline to Online when powerIn->ElectricalPower;
            transition Online to Offline when not powerIn->ElectricalPower;
        }

        perform CommState;
    }

    // ===== Habitation Module =====
    part def HabitationModule {
        port powerIn : ~PowerPort;
        port atmosphereIn : ~AtmospherePort;
        port waterIn : ~WaterPort;
        port thermalOut : ThermalPort;
        port dataOut : DataPort;

        attribute crewCapacity : Integer = 3;
        attribute volume : VolumeValue = 100.0;
        attribute currentCrew : Integer = 0;
        attribute powerConsumption : PowerValue = 3.0;
    }

    part def HabitationModules {
        port powerIn : ~PowerPort;
        port atmosphereIn : ~AtmospherePort;
        port waterIn : ~WaterPort;
        port thermalOut : ThermalPort;
        port dataOut : DataPort;

        part modules : HabitationModule[2];

        binding modules.powerIn to powerIn;
        binding modules.atmosphereIn to atmosphereIn;
        binding modules.waterIn to waterIn;
        binding modules.thermalOut to thermalOut;
        binding modules.dataOut to dataOut;
    }

    // ===== Research Laboratory =====
    part def ResearchLaboratory {
        port powerIn : ~PowerPort;
        port atmosphereIn : ~AtmospherePort;
        port waterIn : ~WaterPort;
        port thermalOut : ThermalPort;
        port scienceOut : ScienceDataPort;

        attribute experimentCount : Integer = 0;
        attribute powerConsumption : PowerValue = 5.0;
        attribute labVolume : VolumeValue = 80.0;
    }

    part def ResearchLaboratories {
        port powerIn : ~PowerPort;
        port atmosphereIn : ~AtmospherePort;
        port waterIn : ~WaterPort;
        port thermalOut : ThermalPort;
        port scienceOut : ScienceDataPort;

        part labs : ResearchLaboratory[3];

        binding labs.powerIn to powerIn;
        binding labs.atmosphereIn to atmosphereIn;
        binding labs.waterIn to waterIn;
        binding labs.thermalOut to thermalOut;
        binding labs.scienceOut to scienceOut;
    }

    // ===== ISS =====
    part def ISS {
        port groundLink : DataPort;

        part solarPowerSystem : SolarPowerSystem;
        part eclss : ECLSS;
        part thermalControl : ThermalControlSystem;
        part gnc : GNC;
        part propulsion : PropulsionModule;
        part comms : CommunicationsSystem;
        part habitation : HabitationModules;
        part laboratories : ResearchLaboratories;

        attribute orbitalAltitude : AltitudeValue = 408.0;
        attribute stationAttitude : AttitudeValue = 0.0;
        attribute totalPower : PowerValue;
        attribute crewOnboard : Integer = 7;
        attribute operationalStatus : String = "Nominal";
        attribute missionDuration : Real = 0.0;

        // Power distribution
        connect solarPowerSystem.powerOut to eclss.powerIn;
        connect solarPowerSystem.powerOut to thermalControl.powerIn;
        connect solarPowerSystem.powerOut to gnc.powerIn;
        connect solarPowerSystem.powerOut to propulsion.powerIn;
        connect solarPowerSystem.powerOut to comms.powerIn;
        connect solarPowerSystem.powerOut to habitation.powerIn;
        connect solarPowerSystem.powerOut to laboratories.powerIn;

        // Atmosphere distribution
        connect eclss.atmosphereOut to habitation.atmosphereIn;
        connect eclss.atmosphereOut to laboratories.atmosphereIn;

        // Water distribution
        connect eclss.waterOut to habitation.waterIn;
        connect eclss.waterOut to laboratories.waterIn;

        // Thermal management
        connect habitation.thermalOut to thermalControl.thermalIn;
        connect laboratories.thermalOut to thermalControl.thermalIn;
        connect eclss.thermalOut to thermalControl.thermalIn;

        // Data routing
        connect gnc.dataOut to comms.telemetryIn;
        connect laboratories.scienceOut to comms.scienceIn;
        binding comms.groundLink to groundLink;

        // GNC to Propulsion command
        connect gnc.thrustCmd to propulsion.thrustCmdIn;

        // ISS operational state machine
        state def ISSOperationalState {
            initial Initialization;
            state NominalOperations {
                parallel PowerManagement {
                    initial PowerCheck;
                    state PowerStable;
                    state PowerLow;
                    transition PowerCheck to PowerStable when solarPowerSystem.totalPower >= 75.0;
                    transition PowerStable to PowerLow when solarPowerSystem.totalPower < 75.0;
                    transition PowerLow to PowerStable when solarPowerSystem.totalPower >= 75.0;
                }
                parallel LifeSupport {
                    initial LifeSupportCheck;
                    state HabitabilityMaintained;
                    state LifeSupportDegraded;
                    transition LifeSupportCheck to HabitabilityMaintained when eclss.oxygenProductionRate >= 0.001;
                    transition HabitabilityMaintained to LifeSupportDegraded when eclss.oxygenProductionRate < 0.001;
                    transition LifeSupportDegraded to HabitabilityMaintained when eclss.oxygenProductionRate >= 0.001;
                }
                parallel ThermalRegulation {
                    initial ThermalCheck;
                    state TemperatureStable;
                    state TemperatureAdjusting;
                    transition ThermalCheck to TemperatureStable when thermalControl.internalTemp <= 297.0;
                    transition TemperatureStable to TemperatureAdjusting when thermalControl.internalTemp > 297.0;
                    transition TemperatureAdjusting to TemperatureStable when thermalControl.internalTemp <= 297.0;
                }
                parallel OrbitMaintenance {
                    initial OrbitCheck;
                    state AltitudeMonitoring;
                    state ReboostPlanned;
                    transition OrbitCheck to AltitudeMonitoring when orbitalAltitude >= 400.0;
                    transition AltitudeMonitoring to ReboostPlanned when orbitalAltitude < 400.0;
                    transition ReboostPlanned to AltitudeMonitoring when orbitalAltitude >= 405.0;
                }
                parallel Communications {
                    initial CommCheck;
                    state LinkActive;
                    state LinkStandby;
                    transition CommCheck to LinkActive when comms.downlinkRate > 0;
                    transition LinkActive to LinkStandby when not comms.downlinkRate > 0;
                    transition LinkStandby to LinkActive when comms.downlinkRate > 0;
                }
            }
            state Alert;
            state Emergency;

            transition Initialization to NominalOperations when solarPowerSystem.totalPower > 0;
            transition NominalOperations to Alert when eclss.oxygenProductionRate < 0.001 or thermalControl.internalTemp > 303.0 or orbitalAltitude < 380.0;
            transition Alert to NominalOperations when eclss.oxygenProductionRate >= 0.001 and thermalControl.internalTemp <= 303.0 and orbitalAltitude >= 380.0;
            transition Alert to Emergency when thermalControl.internalTemp > 313.0 or eclss.oxygenProductionRate < 0.0001;
            transition Emergency to Alert when thermalControl.internalTemp <= 313.0 and eclss.oxygenProductionRate >= 0.0001;
        }

        perform ISSOperationalState;

        action def MonitorVitals {
            out power : PowerValue;
            out oxygenRate : MassFlowValue;
            out co2Rate : MassFlowValue;
            out internalTemp : TemperatureValue;
            out altitude : AltitudeValue;
            out attitude : AttitudeValue;

            action checkPower {
                out power : PowerValue;
            }
            then action checkAtmosphere {
                out oxygenRate : MassFlowValue;
                out co2Rate : MassFlowValue;
            }
            then action checkThermal {
                out internalTemp : TemperatureValue;
            }
            then action checkOrbit {
                out altitude : AltitudeValue;
                out attitude : AttitudeValue;
            }
        }

        action def TakeCorrectiveAction {
            in power : PowerValue;
            in oxygenRate : MassFlowValue;
            in internalTemp : TemperatureValue;
            in altitude : AltitudeValue;

            if power < 75.0 {
                action adjustSolarPanels;
            }
            if oxygenRate < 0.001 {
                action activateCO2Scrubber;
            }
            if altitude < 400.0 {
                action planReboost;
            }
        }

        perform MonitorVitals;
        perform TakeCorrectiveAction;
    }

    // ===== Requirements =====
    requirement def PowerGenerationRequirement {
        subject solarPowerSystem : SolarPowerSystem;
        objective 'Generate sufficient electrical power for all ISS systems';
        require solarPowerSystem.totalPower >= 75.0;
        require solarPowerSystem.arrays->size() == 8;
    }

    requirement def LifeSupportRequirement {
        subject eclss : ECLSS;
        objective 'Maintain habitable atmosphere and water supply for crew survival';
        require eclss.oxygenProductionRate >= 0.001;
        require eclss.co2ScrubRate >= 0.002;
        require eclss.waterRecycleRate >= 0.005;
        require eclss.cabinPressure >= 95.0;
        require eclss.cabinPressure <= 105.0;
    }

    requirement def ThermalControlRequirement {
        subject thermalControl : ThermalControlSystem;
        objective 'Maintain stable internal temperature within habitable range';
        require thermalControl.internalTemp >= 291.0;
        require thermalControl.internalTemp <= 297.0;
        require thermalControl.radiatorArea >= 1000.0;
    }

    requirement def OrbitMaintenanceRequirement {
        subject gnc : GNC;
        objective 'Maintain operational altitude and correct attitude';
        require gnc.currentAltitude >= 380.0;
        require gnc.currentAltitude <= 420.0;
        require gnc.orbitalVelocity >= 7600.0;
    }

    requirement def PropulsionRequirement {
        subject propulsion : PropulsionModule;
        objective 'Perform periodic reboosts to counteract atmospheric drag';
        require propulsion.maxThrust >= 300.0;
        require propulsion.propellantMass > 0;
    }

    requirement def CommunicationsRequirement {
        subject comms : CommunicationsSystem;
        objective 'Maintain data link with ground control for telemetry and commands';
        require comms.downlinkRate >= 10.0;
        require comms.uplinkRate >= 1.0;
    }

    requirement def CrewHabitabilityRequirement {
        subject habitation : HabitationModules;
        objective 'Provide adequate living quarters for crew';
        require habitation.modules->size() >= 2;
    }

    requirement def ScienceCapabilityRequirement {
        subject laboratories : ResearchLaboratories;
        objective 'Support scientific research in microgravity';
        require laboratories.labs->size() >= 3;
    }

    requirement def ISSRequirement {
        subject iss : ISS;
        objective 'Function as self-sustaining outpost in space for crew and scientific experiments';

        satisfy PowerGenerationRequirement by iss.solarPowerSystem;
        satisfy LifeSupportRequirement by iss.eclss;
        satisfy ThermalControlRequirement by iss.thermalControl;
        satisfy OrbitMaintenanceRequirement by iss.gnc;
        satisfy PropulsionRequirement by iss.propulsion;
        satisfy CommunicationsRequirement by iss.comms;
        satisfy CrewHabitabilityRequirement by iss.habitation;
        satisfy ScienceCapabilityRequirement by iss.laboratories;
    }
}
