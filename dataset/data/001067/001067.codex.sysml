package GaseousIonizationDetectorModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricFieldStrength :> ISQ::electricFieldStrength {
        unit = V_per_m;
    }

    attribute def GasPressure :> ISQ::pressure {
        unit = Pa;
    }

    attribute def GasTemperature :> ISQ::thermodynamicTemperature {
        unit = K;
    }

    attribute def IonizationEnergy :> ISQ::energy {
        unit = eV;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = V;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = A;
    }

    attribute def Charge :> ISQ::electricCharge {
        unit = C;
    }

    attribute def CountRate :> ScalarValues::Real {
        unit = Hz;
    }

    attribute def TimeInterval :> ISQ::time {
        unit = s;
    }

    attribute def Length :> ISQ::length {
        unit = m;
    }

    attribute def Energy :> ISQ::energy {
        unit = J;
    }

    item def IonizingRadiation {
        attribute particleKind : String;
        attribute energy : Energy;
        attribute arrivalDirection : String;
    }

    item def PrimaryIonPair {
        attribute electronCharge : Charge;
        attribute positiveIonCharge : Charge;
        attribute creationEnergy : IonizationEnergy;
        attribute creationPosition : Length;
        attribute creationTime : TimeInterval;
    }

    item def ElectronAvalanche {
        attribute multiplicationGain : Real;
        attribute totalCharge : Charge;
        attribute driftTime : TimeInterval;
    }

    item def DetectorPulse {
        attribute amplitude : Voltage;
        attribute chargeIntegral : Charge;
        attribute riseTime : TimeInterval;
        attribute timestamp : TimeInterval;
        attribute inferredEnergy : Energy;
    }

    item def DetectorStatus {
        attribute highVoltageEnabled : Boolean;
        attribute gasFlowHealthy : Boolean;
        attribute pressureStable : Boolean;
        attribute readyForCounting : Boolean;
        attribute faultCode : String;
    }

    port def RadiationInputPort {
        in item radiation : IonizingRadiation;
    }

    port def GasPort {
        in item fillGas : GasMixture;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrentLimit : ElectricCurrent;
    }

    port def SignalPort {
        out item pulse : DetectorPulse;
    }

    port def StatusPort {
        out item status : DetectorStatus;
    }

    item def GasMixture {
        attribute nobleGasFraction : Real;
        attribute quenchGasFraction : Real;
        attribute pressure : GasPressure;
        attribute temperature : GasTemperature;
        attribute meanIonizationEnergy : IonizationEnergy;
    }

    part def Cathode {
        attribute material : String;
        attribute innerRadius : Length;
        attribute activeLength : Length;
        attribute biasVoltage : Voltage;
    }

    part def AnodeWire {
        attribute material : String;
        attribute radius : Length;
        attribute activeLength : Length;
        attribute biasVoltage : Voltage;
        attribute surfaceField : ElectricFieldStrength;
    }

    part def GasVolume {
        port gasIn : GasPort;
        attribute mixture : GasMixture;
        attribute activeVolumeLength : Length;
        attribute activeVolumeRadius : Length;
        attribute nominalPressure : GasPressure = 101325 [Pa];
        attribute nominalTemperature : GasTemperature = 293.15 [K];
        attribute primaryIonPairYield : Real;
    }

    part def HighVoltageSupply {
        port powerIn : ElectricalPowerPort;
        attribute outputVoltage : Voltage;
        attribute maxCurrent : ElectricCurrent;
        attribute ripple : Voltage;
        attribute enabled : Boolean;

        action def RegulateVoltage {
            in attribute requestedVoltage : Voltage;
            out attribute regulatedVoltage : Voltage;
        }
    }

    part def FieldCage {
        attribute cathodePotential : Voltage;
        attribute anodePotential : Voltage;
        attribute averageField : ElectricFieldStrength;
        attribute fieldUniformityError : Real;
    }

    part def ChargeCollectionRegion {
        attribute electronDriftVelocity : Real;
        attribute ionDriftVelocity : Real;
        attribute collectionEfficiency : Real;

        action def DriftAndCollectCharge {
            in item ionPair : PrimaryIonPair;
            out item avalanche : ElectronAvalanche;
        }
    }

    part def FrontEndElectronics {
        port signalOut : SignalPort;
        attribute chargeSensitivity : Real;
        attribute shapingTime : TimeInterval;
        attribute noiseEquivalentCharge : Charge;
        attribute discriminatorThreshold : Voltage;

        action def ShapeAndDiscriminate {
            in item avalanche : ElectronAvalanche;
            out item pulse : DetectorPulse;
        }
    }

    part def GasHandlingSubsystem {
        port gasSupply : GasPort;
        attribute flowRate : Real;
        attribute purifierEfficiency : Real;
        attribute pressureRegulationError : GasPressure;
        attribute leakRate : Real;

        action def MaintainGasQuality {
            out item stableGas : GasMixture;
        }
    }

    part def Controller {
        port statusOut : StatusPort;
        attribute targetVoltage : Voltage;
        attribute measuredCountRate : CountRate;
        attribute inhibitCounting : Boolean;

        state def DetectorOperatingState {
            state Off;
            state GasPurge;
            state RampHighVoltage;
            state Ready;
            state Counting;
            state Fault;

            transition first Off;

            transition Off_to_GasPurge
                first Off
                then GasPurge;

            transition GasPurge_to_RampHighVoltage
                first GasPurge
                accept DetectorStatus
                if gasFlowHealthy
                then RampHighVoltage;

            transition RampHighVoltage_to_Ready
                first RampHighVoltage
                accept DetectorStatus
                if highVoltageEnabled and pressureStable
                then Ready;

            transition Ready_to_Counting
                first Ready
                accept IonizingRadiation
                then Counting;

            transition Counting_to_Ready
                first Counting
                after 1 [s]
                then Ready;

            transition Any_to_Fault
                first Ready
                accept DetectorStatus
                if not gasFlowHealthy or not pressureStable
                then Fault;

            transition Fault_to_Off
                first Fault
                then Off;
        }

        action def EvaluateReadiness {
            in item statusInput : DetectorStatus;
            out attribute countingAllowed : Boolean;
        }
    }

    part def GaseousIonizationDetector {
        port radiationIn : RadiationInputPort;
        port electricalPower : ElectricalPowerPort;
        port detectorSignal : SignalPort;
        port detectorStatus : StatusPort;

        part cathode : Cathode {
            attribute material = "stainless steel";
            attribute innerRadius = 0.012 [m];
            attribute activeLength = 0.18 [m];
            attribute biasVoltage = 0 [V];
        }

        part anode : AnodeWire {
            attribute material = "tungsten";
            attribute radius = 0.0000125 [m];
            attribute activeLength = 0.18 [m];
            attribute biasVoltage = 1850 [V];
            attribute surfaceField = 3000000 [V_per_m];
        }

        part gasVolume : GasVolume {
            attribute activeVolumeLength = 0.18 [m];
            attribute activeVolumeRadius = 0.012 [m];
            attribute primaryIonPairYield = 32.0;
        }

        part gasHandling : GasHandlingSubsystem {
            attribute flowRate = 2.0;
            attribute purifierEfficiency = 0.995;
            attribute pressureRegulationError = 50 [Pa];
            attribute leakRate = 0.000001;
        }

        part highVoltage : HighVoltageSupply {
            attribute outputVoltage = 1850 [V];
            attribute maxCurrent = 0.00001 [A];
            attribute ripple = 0.2 [V];
            attribute enabled = true;
        }

        part fieldCage : FieldCage {
            attribute cathodePotential = 0 [V];
            attribute anodePotential = 1850 [V];
            attribute averageField = 154000 [V_per_m];
            attribute fieldUniformityError = 0.04;
        }

        part collectionRegion : ChargeCollectionRegion {
            attribute electronDriftVelocity = 45000.0;
            attribute ionDriftVelocity = 120.0;
            attribute collectionEfficiency = 0.98;
        }

        part electronics : FrontEndElectronics {
            attribute chargeSensitivity = 1000000000000.0;
            attribute shapingTime = 0.000001 [s];
            attribute noiseEquivalentCharge = 0.000000000000001 [C];
            attribute discriminatorThreshold = 0.015 [V];
        }

        part controller : Controller {
            attribute targetVoltage = 1850 [V];
            attribute measuredCountRate = 0 [Hz];
            attribute inhibitCounting = false;
        }

        connect electricalPower to highVoltage.powerIn;
        connect gasHandling.gasSupply to gasVolume.gasIn;
        connect electronics.signalOut to detectorSignal;
        connect controller.statusOut to detectorStatus;

        action def DetectIonizingRadiation {
            in item incidentRadiation : IonizingRadiation;
            out item measuredPulse : DetectorPulse;

            action createIonPairs {
                in item radiation : IonizingRadiation;
                out item ionPair : PrimaryIonPair;
            }

            action multiplyCharge {
                in item ionPair : PrimaryIonPair;
                out item avalanche : ElectronAvalanche;
            }

            action produceElectricalPulse {
                in item avalanche : ElectronAvalanche;
                out item pulse : DetectorPulse;
            }

            flow incidentRadiation to createIonPairs.radiation;
            flow createIonPairs.ionPair to multiplyCharge.ionPair;
            flow multiplyCharge.avalanche to produceElectricalPulse.avalanche;
            flow produceElectricalPulse.pulse to measuredPulse;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject detector : GaseousIonizationDetector;

        doc
        /* The gaseous ionization detector shall convert incident ionizing radiation into measurable electrical pulses by allowing radiation to ionize a controlled gas volume, collecting the resulting charge carriers under an electric field, and producing output pulses suitable for counting and energy-related analysis. */

        require constraint {
            detector.gasVolume.nominalPressure > 90000 [Pa] and
            detector.gasVolume.nominalPressure < 120000 [Pa] and
            detector.highVoltage.outputVoltage > 500 [V] and
            detector.collectionRegion.collectionEfficiency >= 0.95
        }
    }

    requirement def GasIntegrityRequirement {
        subject detector : GaseousIonizationDetector;

        doc
        /* The detector shall maintain a stable gas composition and pressure so that ionization yield and charge collection remain repeatable during operation. */

        require constraint {
            detector.gasHandling.purifierEfficiency >= 0.99 and
            detector.gasHandling.pressureRegulationError <= 100 [Pa]
        }
    }

    requirement def SignalGenerationRequirement {
        subject detector : GaseousIonizationDetector;

        doc
        /* Each valid ionizing radiation interaction that deposits sufficient energy in the gas shall produce a shaped electrical pulse above the discriminator threshold. */

        require constraint {
            detector.electronics.discriminatorThreshold > detector.electronics.noiseEquivalentCharge * detector.electronics.chargeSensitivity
        }
    }

    requirement def ElectricalSafetyRequirement {
        subject detector : GaseousIonizationDetector;

        doc
        /* The high-voltage supply shall limit current to prevent damage during discharge or gas breakdown conditions. */

        require constraint {
            detector.highVoltage.maxCurrent <= 0.00001 [A]
        }
    }

    requirement def ReadinessRequirement {
        subject detector : GaseousIonizationDetector;

        doc
        /* The detector shall report ready status only when gas flow is healthy, pressure is stable, and high voltage is enabled. */

        require constraint {
            detector.controller.inhibitCounting == false implies detector.highVoltage.enabled == true
        }
    }

    satisfy PrimaryFunctionRequirement by GaseousIonizationDetector;
    satisfy GasIntegrityRequirement by GaseousIonizationDetector;
    satisfy SignalGenerationRequirement by GaseousIonizationDetector;
    satisfy ElectricalSafetyRequirement by GaseousIonizationDetector;
    satisfy ReadinessRequirement by GaseousIonizationDetector;
}