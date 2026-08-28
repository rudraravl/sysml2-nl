package GasolineAdditiveSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ===== Value Types =====
    value type OctaneRating :> Real {
        doc
            /// Dimensionless anti-knock index of gasoline (typical 87-97).
        constraint { self >= 0 and self <= 120 }
    }

    value type AdditiveConcentration :> Real {
        doc
            /// Volumetric fraction of additive in blended fuel (range 0..1).
        constraint { self >= 0 and self <= 1 }
    }

    value type DosingRate :> Real {
        doc
            /// Volumetric flow rate of additive from the dosing pump in L/s.
        constraint { self >= 0 }
    }

    // ===== Item Definitions =====
    item def AdditiveChemicalType :> String;

    item def BaseGasoline {
        attribute octaneRating : OctaneRating[1] = 87;
        attribute temperature : TemperatureValue[1] = 293.15 [K];
    }

    item def Additive {
        attribute chemicalType : AdditiveChemicalType[1];
        attribute octanePotency : Real[1];
        attribute cleaningEffectiveness : Real[1];
    }

    item def DetergentCleaner :> Additive {
        redefines chemicalType = "Detergent Cleaner";
        redefines octanePotency = 2.0;
        redefines cleaningEffectiveness = 0.95;
    }

    item def OctaneBooster :> Additive {
        redefines chemicalType = "Octane Booster";
        redefines octanePotency = 10.0;
        redefines cleaningEffectiveness = 0.05;
    }

    item def BlendedFuel {
        attribute octaneRating : OctaneRating[1];
        attribute additiveConcentration : AdditiveConcentration[1];
        attribute temperature : TemperatureValue[1] = 293.15 [K];
    }

    // ===== Signal Definitions =====
    signal def FlowReading {
        attribute detected : Boolean[1];
        attribute flowRate : DosingRate[1];
        attribute timestamp : TimeValue[1];
    }

    signal def QualityReading {
        attribute octaneRating : OctaneRating[1];
        attribute additiveConcentration : AdditiveConcentration[1];
        attribute timestamp : TimeValue[1];
    }

    signal def DosingCommand {
        attribute enable : Boolean[1];
        attribute dosingRate : DosingRate[1];
    }

    signal def AlarmMessage {
        attribute severity : String[1];
        attribute text : String[1];
        attribute timestamp : TimeValue[1];
    }

    // ===== Port Definitions =====
    port def FuelInlet {
        in flow fuel;
    }

    port def FuelOutlet {
        out flow fuel;
    }

    port def AdditiveInlet {
        in flow additive : Additive;
    }

    port def AdditiveOutlet {
        out flow additive : Additive;
    }

    port def BlendedFuelOutlet {
        out flow blendedFuel : BlendedFuel;
    }

    port def FlowReportPort {
        out signal reading : FlowReading;
    }

    port def FlowListenPort {
        in signal reading : FlowReading;
    }

    port def QualityReportPort {
        out signal reading : QualityReading;
    }

    port def QualityListenPort {
        in signal reading : QualityReading;
    }

    port def DosingCommandPort {
        out signal command : DosingCommand;
    }

    port def DosingCommandReceivePort {
        in signal command : DosingCommand;
    }

    port def AlarmPort {
        out signal alarm : AlarmMessage;
    }

    // ===== Requirements =====
    requirement def OctaneTarget {
        doc
            /// The system shall raise the octane rating of the gasoline
            /// to at least the specified target value.
        subject finalFuel : BlendedFuel;
        attribute targetOctane : OctaneRating[1] = 93;
        constraint { finalFuel.octaneRating >= targetOctane }
    }

    requirement def HomogeneousBlend {
        doc
            /// The mixing chamber shall produce a homogeneous blend
            /// with an additive concentration within the specified range.
        subject finalFuel : BlendedFuel;
        attribute minConcentration : AdditiveConcentration[1] = 0.005;
        attribute maxConcentration : AdditiveConcentration[1] = 0.05;
        attribute homogeneityFactor : Real[1] = 0.98;
        constraint {
            finalFuel.additiveConcentration >= minConcentration
                and finalFuel.additiveConcentration <= maxConcentration
        }
    }

    requirement def DosingPrecision {
        doc
            /// The dosing pump shall deliver additive with at most 2% rate deviation.
        subject dosingPump : DosingPump;
        attribute maxError : Real[1] = 0.02;
        constraint { dosingPump.precision <= maxError }
    }

    requirement def TreatmentCycleTime {
        doc
            /// The treatment cycle shall complete within 30 seconds of detecting fuel flow.
        subject system : GasolineAdditiveSystem;
        attribute maxDuration : TimeValue[1] = 30 [s];
    }

    requirement def SafetyShutdown {
        doc
            /// The system shall disable the dosing pump when fuel flow stops.
        subject system : GasolineAdditiveSystem;
        attribute maximumResponseTime : TimeValue[1] = 2 [s];
    }

    // ===== Part Definitions =====
    part def FuelTank {
        port fuelOutlet : FuelOutlet;
        attribute capacity : VolumeValue[1] = 5000 [L];
        attribute currentLevel : VolumeValue[1] = 5000 [L];
        attribute storedFuelType : String[1] = "Base Gasoline";
        attribute operatingPressure : PressureValue[1] = 101300 [Pa];

        action def supplyFuel {
            out flow fuel;
            constraint { currentLevel > 0 [L] }
        }

        action def refill {
            in flow newFuel;
        }
    }

    part def AdditiveReservoir {
        port additiveOutlet : AdditiveOutlet;
        attribute capacity : VolumeValue[1] = 50 [L];
        attribute currentLevel : VolumeValue[1] = 50 [L];
        attribute containedAdditiveType : AdditiveChemicalType[1] = "Octane Booster";
        attribute potency : Real[1] = 10.0;
        attribute minimumReserveLevel : VolumeValue[1] = 5 [L];

        action def dispenseAdditive {
            out flow additive : Additive;
            constraint { currentLevel > minimumReserveLevel }
        }
    }

    part def FlowSensor {
        port fuelInlet : FuelInlet;
        port fuelOutlet : FuelOutlet;
        port flowReport : FlowReportPort;
        attribute detectionThreshold : DosingRate[1] = 0.1;
        attribute samplingInterval : TimeValue[1] = 0.5 [s];
        attribute lastFlowRate : DosingRate[1] = 0;
        attribute lastDetected : Boolean[1] = false;
        attribute calibrationFactor : Real[1] = 1.0;

        action def detectFlow {
            in flow fuel;
            out signal reading : FlowReading;
        }

        action def calibrate {
            in factor : Real;
        }
    }

    part def QualitySensor {
        port baseFuelIn : FuelInlet;
        port blendedFuelIn : FuelInlet;
        port baseFuelOut : FuelOutlet;
        port blendedFuelOut : FuelOutlet;
        port baseQualityReport : QualityReportPort;
        port blendedQualityReport : QualityReportPort;
        attribute samplingInterval : TimeValue[1] = 1 [s];
        attribute measurementAccuracy : Real[1] = 0.1;
        attribute calibrationOffset : OctaneRating[1] = 0;
        attribute lastBaseOctane : OctaneRating[1] = 87;
        attribute lastBlendedOctane : OctaneRating[1] = 87;
        attribute lastBlendedConcentration : AdditiveConcentration[1] = 0;

        action def measureBaseQuality {
            in flow baseFuel;
            out signal reading : QualityReading;
        }

        action def measureBlendedQuality {
            in flow blendedFuel;
            out signal reading : QualityReading;
        }

        action def calibrate {
            in offset : OctaneRating;
        }
    }

    part def DosingPump {
        port additiveIn : AdditiveInlet;
        port additiveOut : AdditiveOutlet;
        port commandIn : DosingCommandReceivePort;
        attribute maxRate : DosingRate[1] = 5;
        attribute currentRate : DosingRate[1] = 0;
        attribute enabled : Boolean[1] = false;
        attribute precision : Real[1] = 0.02;
        attribute operatingPressure : PressureValue[1] = 500000 [Pa];
        attribute totalDispensed : VolumeValue[1] = 0 [L];

        action def doseAdditive {
            in signal command : DosingCommand;
            in flow additive : Additive;
            out flow dosedAdditive : Additive;
            constraint {
                command.dosingRate <= maxRate
                    and command.dosingRate >= 0
            }
        }

        action def disable {
            doc
                /// Stop dosing immediately.
        }
    }

    part def MixingChamber {
        port baseFuelIn : FuelInlet;
        port additiveIn : AdditiveInlet;
        port blendedFuelOut : BlendedFuelOutlet;
        attribute volume : VolumeValue[1] = 10 [L];
        attribute mixingEfficiency : Real[1] = 0.98;
        attribute dwellTime : TimeValue[1] = 2 [s];
        attribute operatingPressure : PressureValue[1] = 300000 [Pa];

        action def mix {
            in flow baseFuel;
            in flow additive : Additive;
            out flow blendedFuel : BlendedFuel;
            constraint { mixingEfficiency >= 0.9 }
        }
    }

    part def SystemController {
        port flowListen : FlowListenPort;
        port baseQualityListen : QualityListenPort;
        port blendedQualityListen : QualityListenPort;
        port dosingCommand : DosingCommandPort;
        port alarmOut : AlarmPort;

        attribute targetOctane : OctaneRating[1] = 93;
        attribute minAdditiveConcentration : AdditiveConcentration[1] = 0.005;
        attribute maxDosingRate : DosingRate[1] = 5;
        attribute dosingGain : Real[1] = 0.1;
        attribute currentDosingRate : DosingRate[1] = 0;
        attribute lastBaseOctane : OctaneRating[1] = 87;
        attribute lastBlendedOctane : OctaneRating[1] = 87;
        attribute lastBlendedConcentration : AdditiveConcentration[1] = 0;
        attribute correctionFactor : Real[1] = 1.0;
        attribute cyclesCompleted : Integer[1] = 0;
        attribute flowDetected : Boolean[1] = false;

        state machine controllerBehavior {
            state idle;
            state monitoring;
            state treating;
            state verifying;
            state faulted;

            transition initial to idle;
            transition idle to monitoring
                when flowListen.reading.detected == true;
            transition monitoring to treating
                when baseQualityListen.reading.octaneRating < targetOctane;
            transition treating to verifying
                after 5 [s];
            transition verifying to monitoring
                when blendedQualityListen.reading.octaneRating >= targetOctane
                    and blendedQualityListen.reading.additiveConcentration >= minAdditiveConcentration;
            transition verifying to treating
                when blendedQualityListen.reading.octaneRating < targetOctane;
            transition monitoring to idle
                when flowListen.reading.detected == false;
            transition treating to faulted
                when currentDosingRate > maxDosingRate;
            transition faulted to idle
                when flowListen.reading.detected == false;
        }

        action def calculateDosage {
            in baseOctane : OctaneRating;
            in target : OctaneRating;
            in potency : Real;
            in fuelFlowRate : DosingRate;
            out rate : DosingRate;
            constraint { rate <= maxDosingRate and rate >= 0 }
        }

        action def verifyQuality {
            in blendedReading : QualityReading;
            in target : OctaneRating;
            in minConc : AdditiveConcentration;
            out pass : Boolean;
            constraint {
                pass == (blendedReading.octaneRating >= target
                    and blendedReading.additiveConcentration >= minConc)
            }
        }

        action def sendAlarm {
            in severity : String;
            in text : String;
            out signal alarm : AlarmMessage;
        }
    }

    // ===== Top-Level System =====
    part def GasolineAdditiveSystem {
        part fuelTank : FuelTank;
        part additiveReservoir : AdditiveReservoir;
        part flowSensor : FlowSensor;
        part qualitySensor : QualitySensor;
        part dosingPump : DosingPump;
        part mixingChamber : MixingChamber;
        part controller : SystemController;
        port systemFuelOutlet : BlendedFuelOutlet;

        // Satisfactions of requirements
        satisfy octaneTarget : OctaneTarget;
        satisfy homogeneousBlend : HomogeneousBlend;
        satisfy dosingPrecision : DosingPrecision;
        satisfy treatmentCycleTime : TreatmentCycleTime;
        satisfy safetyShutdown : SafetyShutdown;

        // Physical fuel flow path
        connection fuelTank.fuelOutlet to flowSensor.fuelInlet;
        connection flowSensor.fuelOutlet to qualitySensor.baseFuelIn;
        connection qualitySensor.baseFuelOut to mixingChamber.baseFuelIn;
        connection mixingChamber.blendedFuelOut to qualitySensor.blendedFuelIn;
        connection qualitySensor.blendedFuelOut to systemFuelOutlet;

        // Additive flow path
        connection additiveReservoir.additiveOutlet to dosingPump.additiveIn;
        connection dosingPump.additiveOut to mixingChamber.additiveIn;

        // Signal/control flow
        connection flowSensor.flowReport to controller.flowListen;
        connection qualitySensor.baseQualityReport to controller.baseQualityListen;
        connection qualitySensor.blendedQualityReport to controller.blendedQualityListen;
        connection controller.dosingCommand to dosingPump.commandIn;
    }
}
