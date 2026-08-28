package ISS_Model {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def Power;
        item def Data;
        item def Heat;
        item def Oxygen;
        item def CarbonDioxide;
        item def Water;
        item def Thrust;

        port def PowerPort {
            out power : Power;
        }
        port def DataPort {
            out data : Data;
        }
        port def FluidPort {
            out oxygen : Oxygen;
            in carbonDioxide : CarbonDioxide;
            out water : Water;
        }
        port def ThermalPort {
            out heat : Heat;
        }
        port def ThrustPort {
            out thrust : Thrust;
        }
        port def GroundLinkPort {
            out downlink : Data;
            in uplink : Data;
        }

        part def SolarArray {
            port powerOut : PowerPort;
            perform action trackSun;
        }

        part def SolarPowerSystem {
            part solarArrays[8] : SolarArray;
            port powerOut : PowerPort;
            perform action generatePower;
        }

        part def ECLSS {
            port powerIn : ~PowerPort;
            port atmosphereOut : FluidPort;
            port atmosphereIn : ~FluidPort;
            perform action generateOxygen;
            perform action scrubCO2;
            perform action recycleWater;
        }

        part def HabitationModule {
            port powerIn : ~PowerPort;
            port atmosphereIn : ~FluidPort;
            port atmosphereOut : FluidPort;
            port thermalOut : ThermalPort;
        }

        part def ResearchLab {
            port powerIn : ~PowerPort;
            port atmosphereIn : ~FluidPort;
            port atmosphereOut : FluidPort;
            port thermalOut : ThermalPort;
            port dataOut : DataPort;
        }

        part def Radiator {
            port heatIn : ~ThermalPort;
        }

        part def ThermalControlSystem {
            port powerIn : ~PowerPort;
            port heatIn : ~ThermalPort;
            part radiators : Radiator;
            perform action dissipateHeat;
        }

        part def GNC {
            port powerIn : ~PowerPort;
            port dataOut : DataPort;
            port dataIn : ~DataPort;
            perform action trackPosition;
            perform action maintainAttitude;
        }

        part def PropulsionModule {
            port powerIn : ~PowerPort;
            port dataIn : ~DataPort;
            port thrustOut : ThrustPort;
            perform action reboost;
        }

        part def CommunicationsSystem {
            port powerIn : ~PowerPort;
            port dataIn : ~DataPort;
            port dataOut : DataPort;
            port groundLink : GroundLinkPort;
            perform action transmitData;
            perform action receiveCommands;
        }

        part def ISS {
            attribute orbitalAltitude : Real;
            attribute powerLevel : Real;
            attribute atmosphericComposition : Real;
            attribute co2Level : Real;
            attribute isNominal : Boolean;

            part solarPowerSystem : SolarPowerSystem;
            part eclss : ECLSS;
            part habitationModules : HabitationModule;
            part researchLabs : ResearchLab;
            part thermalControlSystem : ThermalControlSystem;
            part gnc : GNC;
            part propulsionModule : PropulsionModule;
            part communicationsSystem : CommunicationsSystem;

            perform action checkVitals;
            perform action takeAction;
            perform action adjustSolarPanels;
            perform action activateCO2Scrubbers;
            perform action planReboost;

            exhibit state issOperations {
                entry action initial;
                state monitoring {
                    do checkVitals;
                }
                state correctiveAction {
                    do takeAction;
                }
                state nominal {
                    do checkVitals;
                }
                transition initial then monitoring;
                transition monitoring_To_correctiveAction
                    first monitoring
                    then correctiveAction;
                transition correctiveAction_To_monitoring
                    first correctiveAction
                    then monitoring;
                transition monitoring_To_nominal
                    first monitoring
                    then nominal;
                transition nominal_To_monitoring
                    first nominal
                    then monitoring;
            }
        }

        requirement def ISSRequirement {
            subject iss : ISS;
            requirement powerGenerationRequirement {
                doc /* The ISS must generate sufficient power for all systems. */
                constraint { iss.powerLevel >= 1000.0 }
            }
            requirement lifeSupportRequirement {
                doc /* The ECLSS must maintain habitable atmosphere. */
                constraint { iss.co2Level < 0.005 }
            }
            requirement altitudeRequirement {
                doc /* The ISS must maintain operational altitude above 350 km. */
                constraint { iss.orbitalAltitude >= 350.0 }
            }
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        part iss : ISS {
            flow powerFlowEclss of Power from solarPowerSystem.powerOut.power to eclss.powerIn.power;
            flow powerFlowHab of Power from solarPowerSystem.powerOut.power to habitationModules.powerIn.power;
            flow powerFlowRes of Power from solarPowerSystem.powerOut.power to researchLabs.powerIn.power;
            flow powerFlowTherm of Power from solarPowerSystem.powerOut.power to thermalControlSystem.powerIn.power;
            flow powerFlowGnc of Power from solarPowerSystem.powerOut.power to gnc.powerIn.power;
            flow powerFlowProp of Power from solarPowerSystem.powerOut.power to propulsionModule.powerIn.power;
            flow powerFlowComm of Power from solarPowerSystem.powerOut.power to communicationsSystem.powerIn.power;

            flow oxygenFlowHab of Oxygen from eclss.atmosphereOut.oxygen to habitationModules.atmosphereIn.oxygen;
            flow co2FlowHab of CarbonDioxide from habitationModules.atmosphereOut.carbonDioxide to eclss.atmosphereIn.carbonDioxide;
            flow oxygenFlowRes of Oxygen from eclss.atmosphereOut.oxygen to researchLabs.atmosphereIn.oxygen;
            flow co2FlowRes of CarbonDioxide from researchLabs.atmosphereOut.carbonDioxide to eclss.atmosphereIn.carbonDioxide;

            flow heatFlowHab of Heat from habitationModules.thermalOut.heat to thermalControlSystem.heatIn.heat;
            flow heatFlowRes of Heat from researchLabs.thermalOut.heat to thermalControlSystem.heatIn.heat;

            flow dataFlowRes of Data from researchLabs.dataOut.data to communicationsSystem.dataIn.data;
            flow dataFlowGnc of Data from gnc.dataOut.data to communicationsSystem.dataIn.data;
            flow cmdFlowGnc of Data from communicationsSystem.dataOut.data to gnc.dataIn.data;
            flow cmdFlowProp of Data from communicationsSystem.dataOut.data to propulsionModule.dataIn.data;
        }

        requirement issSystemRequirement : ISSRequirement {
            subject :>> iss = Usages::iss;
        }
    }
}
