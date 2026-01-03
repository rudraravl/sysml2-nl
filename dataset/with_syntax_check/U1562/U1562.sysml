package RTGPowerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ConversionEfficiency :> Real;
    attribute def DecayConstant :> Real;
    attribute def SpecificPowerValue :> ISQ::PowerValue;

    item def RadioisotopeIsotope {
        attribute isotopeType : String;
        attribute halfLife :> ISQ::time;
        attribute specificThermalPower :> ISQ::power;
        attribute mass :> ISQ::mass;
    }

    item def ThermoelectricCouple {
        attribute hotJunctionTemp :> ISQ::thermodynamicTemperature;
        attribute coldJunctionTemp :> ISQ::thermodynamicTemperature;
        attribute efficiency : ConversionEfficiency;
        attribute outputVoltage :> ISQ::voltage;
    }

    port def ThermalInputPort {
        in heatFlow :> ISQ::power;
        in temperature :> ISQ::thermodynamicTemperature;
    }

    port def ThermalOutputPort {
        out heatFlow :> ISQ::power;
        out temperature :> ISQ::thermodynamicTemperature;
    }

    port def ElectricalOutputPort {
        out voltage :> ISQ::voltage;
        out current :> ISQ::electricCurrent;
        out power :> ISQ::power;
    }

    part def RadioisotopeHeatSource {
        attribute fuelMass :> ISQ::mass;
        attribute thermalPowerOutput :> ISQ::power;
        attribute surfaceTemperature :> ISQ::thermodynamicTemperature;
        attribute decayRate : DecayConstant;

        port thermalOut : ThermalOutputPort {
            :>> heatFlow = thermalPowerOutput;
            :>> temperature = surfaceTemperature;
        }
    }

    part def ThermoelectricConverterModule {
        attribute numberOfCouples : Integer;
        attribute conversionEfficiency : ConversionEfficiency;
        attribute hotSideTemp :> ISQ::thermodynamicTemperature;
        attribute coldSideTemp :> ISQ::thermodynamicTemperature;

        port thermalIn : ThermalInputPort;
        port thermalOut : ThermalOutputPort;
        port electricalOut : ElectricalOutputPort;
    }

    part def HeatRejectionSystem {
        attribute radiatorArea :> ISQ::area;
        attribute emissivity : Real;
        attribute radiatorTemperature :> ISQ::thermodynamicTemperature;
        attribute rejectedHeat :> ISQ::power;

        port thermalIn : ThermalInputPort;
    }

    part def PowerConditioningUnit {
        attribute inputVoltage :> ISQ::voltage;
        attribute outputVoltage :> ISQ::voltage;
        attribute regulationEfficiency : ConversionEfficiency;

        port electricalIn : ElectricalOutputPort;
        port electricalOut : ElectricalOutputPort;
    }

    action def GenerateThermalEnergy {
        in fuelMass : ISQ::MassValue;
        in specificPower : SpecificPowerValue;
        in operatingTime : ISQ::TimeValue;
        in decayConstant : Real;
        out thermalPower : ISQ::PowerValue;
    }

    action def ConvertThermalToElectrical {
        in thermalInput : ISQ::PowerValue;
        in hotTemp : ISQ::ThermodynamicTemperatureValue;
        in coldTemp : ISQ::ThermodynamicTemperatureValue;
        in efficiency : Real;
        out electricalOutput : ISQ::PowerValue;
        out wasteHeat : ISQ::PowerValue;
    }

    action def RejectWasteHeat {
        in wasteHeat : ISQ::PowerValue;
        in radiatorArea : ISQ::AreaValue;
        in emissivity : Real;
        out radiatorTemp : ISQ::ThermodynamicTemperatureValue;
    }

    action def ConditionPower {
        in rawPower : ISQ::PowerValue;
        in rawVoltage : ISQ::voltage;
        in targetVoltage : ISQ::voltage;
        out conditionedPower : ISQ::PowerValue;
        out conditionedVoltage : ISQ::voltage;
    }

    action def RTGPowerGeneration {
        in missionTime : ISQ::TimeValue;
        out systemPower : ISQ::PowerValue;

        first start;
        then merge continuousOperation;

        action generateHeat : GenerateThermalEnergy {
            in fuelMass = 4.8[SI::kg];
            in specificPower = 420[SI::W];
            in operatingTime = missionTime;
            in decayConstant = 0.008;
            out thermalPower;
        }

        then action convertPower : ConvertThermalToElectrical {
            in thermalInput = generateHeat.thermalPower;
            in hotTemp = 1173[SI::K];
            in coldTemp = 573[SI::K];
            in efficiency = 0.065;
            out electricalOutput;
            out wasteHeat;
        }

        flow convertPower.electricalOutput to conditionOutput.rawPower;

        action rejectHeat : RejectWasteHeat {
            in wasteHeat = convertPower.wasteHeat;
            in radiatorArea = 1.2[SI::'m^2'];
            in emissivity = 0.85;
            out radiatorTemp;
        }

        action conditionOutput : ConditionPower {
            in rawPower;
            in rawVoltage = 30[SI::V];
            in targetVoltage = 28[SI::V];
            out conditionedPower;
            out conditionedVoltage;
        }

        then assign systemPower := conditionOutput.conditionedPower;
        then continuousOperation;
    }

    attribute def EndOfMissionSignal;

    state def RTGOperationalStates {
        entry; then initialization;

        state initialization {
            entry assign status := "Initializing";
        }
        then steadyStateOperation;

        state steadyStateOperation {
            entry assign status := "Nominal Operation";

            state normalOutput;
            state degradedOutput;

            accept when outputPower >= 100[SI::W]
                then normalOutput;

            accept when outputPower < 100[SI::W] and outputPower >= 80[SI::W]
                then degradedOutput;

            accept when outputPower < 80[SI::W]
                then criticalLowPower;

            state criticalLowPower {
                entry assign status := "Critical Low Power";
            }
        }

        accept endOfMissionSignal : EndOfMissionSignal
            then shutdown;

        state shutdown {
            entry assign status := "End of Mission";
        }
        then done;

        attribute status : String;
        attribute outputPower : ISQ::PowerValue;
    }

    part def RTGSystem {
        attribute missionDuration :> ISQ::time;
        attribute beginningOfLifePower :> ISQ::power;
        attribute endOfLifePower :> ISQ::power;

        part heatSource : RadioisotopeHeatSource {
            attribute :>> fuelMass = 4.8[SI::kg];
            attribute :>> thermalPowerOutput = 2016[SI::W];
            attribute :>> surfaceTemperature = 1273[SI::K];
            attribute :>> decayRate = 0.008;
        }

        part converter : ThermoelectricConverterModule {
            attribute :>> numberOfCouples = 144;
            attribute :>> conversionEfficiency = 0.065;
            attribute :>> hotSideTemp = 1173[SI::K];
            attribute :>> coldSideTemp = 573[SI::K];
        }

        part radiator : HeatRejectionSystem {
            attribute :>> radiatorArea = 1.2[SI::'m^2'];
            attribute :>> emissivity = 0.85;
            attribute :>> radiatorTemperature = 573[SI::K];
            attribute :>> rejectedHeat = 1885[SI::W];
        }

        part powerConditioner : PowerConditioningUnit {
            attribute :>> inputVoltage = 30[SI::V];
            attribute :>> outputVoltage = 28[SI::V];
            attribute :>> regulationEfficiency = 0.95;
        }

        port systemElectricalOutput : ElectricalOutputPort {
            :>> voltage = 28[SI::V];
            :>> current = 4.68[SI::A];
            :>> power = 131[SI::W];
        }

        connect heatSource.thermalOut to converter.thermalIn;
        connect converter.thermalOut to radiator.thermalIn;
        connect converter.electricalOut to powerConditioner.electricalIn;
        connect powerConditioner.electricalOut to systemElectricalOutput;

        perform action powerGeneration : RTGPowerGeneration {
            in missionTime : ISQ::TimeValue;
            out systemPower : ISQ::PowerValue;
        }

        exhibit state operationalState : RTGOperationalStates {
            :>> outputPower = powerGeneration.systemPower;
        }
    }

    requirement def ContinuousPowerRequirement {
        doc /* The RTG shall provide continuous electrical power throughout the mission lifetime. */
        subject rtg : RTGSystem;
        require constraint {
            rtg.powerGeneration.systemPower >= rtg.endOfLifePower
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The RTG shall maintain component temperatures within safe operating limits. */
        subject rtg : RTGSystem;
        require constraint {
            rtg.converter.hotSideTemp <= 1273[SI::K]
        }
        require constraint {
            rtg.radiator.radiatorTemperature <= 623[SI::K]
        }
    }

    requirement def PowerOutputRequirement {
        doc /* The RTG shall deliver minimum specified electrical power at end of mission. */
        subject rtg : RTGSystem;
        require constraint {
            rtg.endOfLifePower >= 100[SI::W]
        }
    }

    requirement def MissionLifetimeRequirement {
        doc /* The RTG shall operate reliably for the specified mission duration. */
        subject rtg : RTGSystem;
        require constraint {
            rtg.missionDuration >= 14[SI::yr]
        }
    }

    requirement def ConversionEfficiencyRequirement {
        doc /* The RTG shall maintain minimum thermoelectric conversion efficiency. */
        subject rtg : RTGSystem;
        require constraint {
            rtg.converter.conversionEfficiency >= 0.06
        }
    }

    requirement rtgSystemRequirements {
        doc /* Top-level requirements for the Radioisotope Thermoelectric Generator system. 
               The RTG converts heat from radioactive decay into electrical power for long-duration 
               space missions where solar power is not feasible. */

        require continuousPowerReq : ContinuousPowerRequirement;
        require thermalSafetyReq : ThermalSafetyRequirement;
        require powerOutputReq : PowerOutputRequirement;
        require missionLifetimeReq : MissionLifetimeRequirement;
        require conversionEfficiencyReq : ConversionEfficiencyRequirement;
    }

    part rtgUnit : RTGSystem {
        attribute :>> missionDuration = 14[SI::yr];
        attribute :>> beginningOfLifePower = 131[SI::W];
        attribute :>> endOfLifePower = 100[SI::W];

        satisfy rtgSystemRequirements by self;
    }
}
