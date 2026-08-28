package RTG_Model {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        item def Heat;
        item def ElectricalPower;
        item def ConditionedPower;

        attribute def VoltageValue :> Real;

        port def HeatOutPort { out heat : Heat; }
        port def HeatInPort { in heat : Heat; }
        port def PowerOutPort { out power : ElectricalPower; }
        port def PowerInPort { in power : ElectricalPower; }
        port def ConditionedPowerOutPort { out power : ConditionedPower; }

        part def RadioisotopeHeatSource {
            attribute fuelMass : MassValue = 4.8[kg];
            attribute surfaceTemp : TemperatureValue;
            port heatOut : HeatOutPort;
        }

        part def ThermoelectricConverterModule {
            attribute numCouples : Integer = 144;
            attribute hotSideTemp : TemperatureValue;
            attribute coldSideTemp : TemperatureValue;
            attribute generatedVoltage : VoltageValue;
            port heatIn : HeatInPort;
            port heatOut : HeatOutPort;
            port powerOut : PowerOutPort;
        }

        part def HeatRejectionSystem {
            attribute radiatorArea : AreaValue = 1.2[m^2];
            port heatIn : HeatInPort;
        }

        part def PowerConditioningUnit {
            attribute outputVoltage : VoltageValue = 28[V];
            port powerIn : PowerInPort;
            port powerOut : ConditionedPowerOutPort;
        }

        part def RTG {
            attribute initialPower : PowerValue = 131[W];
            attribute endOfLifePower : PowerValue = 100[W];
            attribute operationalLife : TimeValue = 14[a];
            attribute currentPower : PowerValue;
            attribute elapsedYears : TimeValue;

            part heatSource : RadioisotopeHeatSource;
            part converter : ThermoelectricConverterModule;
            part heatRejection : HeatRejectionSystem;
            part powerConditioning : PowerConditioningUnit;

            connect heatSource.heatOut to converter.heatIn;
            connect converter.heatOut to heatRejection.heatIn;
            connect converter.powerOut to powerConditioning.powerIn;

            exhibit state 'rtg states' : 'RTG States';
        }

        state def 'RTG States';

        action def GenerateHeat {
            in fuel : MassValue;
            out heat : Heat;
        }
        action def ConvertHeatToPower {
            in heat : Heat;
            out power : ElectricalPower;
        }
        action def RejectHeat {
            in heat : Heat;
        }
        action def ConditionPower {
            in rawPower : ElectricalPower;
            out conditionedPower : ConditionedPower;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def PowerOutputRequirement {
            doc /* The RTG shall produce at least the specified minimum power output. */
            subject rtg : RTG;
            attribute minPower : PowerValue;
            require constraint { rtg.currentPower >= minPower }
        }

        requirement def <'REQ-1'> InitialPowerOutput :> PowerOutputRequirement {
            doc /* The RTG shall produce at least 131 watts at the start of the mission. */
            attribute redefines minPower = 131[W];
        }

        requirement def <'REQ-2'> EndOfLifePowerOutput :> PowerOutputRequirement {
            doc /* The RTG shall produce at least 100 watts at the end of its 14-year operational life. */
            attribute redefines minPower = 100[W];
        }

        requirement def <'REQ-3'> OperationalLifeRequirement {
            doc /* The RTG shall be designed for an operational life of 14 years. */
            subject rtg : RTG;
            require constraint { rtg.operationalLife >= 14[a] }
        }

        requirement def <'REQ-4'> FuelMassRequirement {
            doc /* The radioisotope heat source shall contain 4.8 kg of radioactive fuel. */
            subject heatSource : RadioisotopeHeatSource;
            require constraint { heatSource.fuelMass == 4.8[kg] }
        }

        requirement def <'REQ-5'> ThermoelectricCouplesRequirement {
            doc /* The thermoelectric converter module shall contain 144 thermoelectric couples. */
            subject converter : ThermoelectricConverterModule;
            require constraint { converter.numCouples == 144 }
        }

        requirement def <'REQ-6'> RadiatorAreaRequirement {
            doc /* The heat rejection system radiator shall have an area of 1.2 square meters. */
            subject heatRejection : HeatRejectionSystem;
            require constraint { heatRejection.radiatorArea == 1.2[m^2] }
        }

        requirement def <'REQ-7'> ConditionedVoltageRequirement {
            doc /* The power conditioning unit shall output a stable 28V conditioned voltage. */
            subject powerConditioning : PowerConditioningUnit;
            require constraint { powerConditioning.outputVoltage == 28[V] }
        }

        requirement def <'REQ-8'> HeatFlowRequirement {
            doc /* Waste heat from the converter cold side shall be rejected to space via the radiator. */
            subject heatRejection : HeatRejectionSystem;
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        requirement initialPowerReq : InitialPowerOutput;
        requirement endOfLifePowerReq : EndOfLifePowerOutput;
        requirement operationalLifeReq : OperationalLifeRequirement;
        requirement fuelMassReq : FuelMassRequirement;
        requirement thermoelectricCouplesReq : ThermoelectricCouplesRequirement;
        requirement radiatorAreaReq : RadiatorAreaRequirement;
        requirement conditionedVoltageReq : ConditionedVoltageRequirement;
        requirement heatFlowReq : HeatFlowRequirement;

        part rtgInstance : RTG {
            satisfy initialPowerReq by rtgInstance;
            satisfy endOfLifePowerReq by rtgInstance;
            satisfy operationalLifeReq by rtgInstance;
            satisfy fuelMassReq by rtgInstance.heatSource;
            satisfy thermoelectricCouplesReq by rtgInstance.converter;
            satisfy radiatorAreaReq by rtgInstance.heatRejection;
            satisfy conditionedVoltageReq by rtgInstance.powerConditioning;
            satisfy heatFlowReq by rtgInstance.heatRejection;
        }

        state 'rtg states' : 'RTG States' {
            entry; then 'Nominal Operation';
            state 'Nominal Operation' {
                doc /* RTG is operating within expected power range. */
            }
            accept when rtgInstance.currentPower < 0.85 * rtgInstance.initialPower
                then 'Degraded Output';
            state 'Degraded Output' {
                doc /* RTG power output has fallen below 85 percent of initial. */
            }
            accept when rtgInstance.currentPower < rtgInstance.endOfLifePower
                then 'Critical Low Power';
            state 'Critical Low Power' {
                doc /* RTG power output is at or below end-of-life threshold. */
            }
            accept when rtgInstance.elapsedYears >= rtgInstance.operationalLife
                then 'Shutdown';
            state 'Shutdown' {
                doc /* RTG has reached end of mission and is powered off. */
            }
        }
    }
}
