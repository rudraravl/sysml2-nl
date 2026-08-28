package IontophoreticDrugDeliverySystem {

    import ScalarValues::*;

    // ===== Units =====
    unit mA;
    unit ohm;
    unit s;
    unit mg;
    unit V;
    unit mW;

    // ===== Value Types =====
    value type ElectricCurrent > Real {
        unit mA;
    }

    value type ElectricalImpedance > Real {
        unit ohm;
    }

    value type DurationValue > Real {
        unit s;
    }

    value type DrugDosage > Real {
        unit mg;
    }

    value type VoltageValue > Real {
        unit V;
    }

    value type PowerValue > Real {
        unit mW;
    }

    // ===== Item Definitions =====
    item def IonizedDrug {
        attribute charge : Integer;
        attribute molecularWeight : Real;
        attribute concentration : Real;
        attribute name : String;
    }

    item def ElectricCurrentFlow {
        attribute magnitude : ElectricCurrent;
        attribute direction : String;
    }

    item def DrugMolecule :> IonizedDrug {
        attribute deliveredAmount : DrugDosage;
    }

    item def TreatmentStatus {
        attribute state : String;
        attribute progress : Real;
        attribute faultCode : Integer;
    }

    // ===== Port Definitions =====
    port def ElectricalPowerPort {
        out voltage : VoltageValue;
        out current : ElectricCurrent;
        in returnCurrent : ElectricCurrent;
    }

    port def ControlSignalPort {
        out command : String;
        in feedback : String;
    }

    port def SensorDataPort {
        out impedance : ElectricalImpedance;
        out currentReading : ElectricCurrent;
        out elapsedTime : DurationValue;
    }

    port def DrugDeliveryPort {
        out drug : IonizedDrug;
        out deliveredDose : DrugDosage;
    }

    port def SkinContactPort {
        attribute contactImpedance : ElectricalImpedance;
        attribute contactQuality : Real;
    }

    port def StatusPort {
        out status : TreatmentStatus;
    }

    // ===== Part Definitions =====

    part def PowerSupply {
        doc /* Battery-powered supply providing electrical energy for iontophoretic delivery */
        port powerOut : ElectricalPowerPort;
        port returnIn : ElectricalPowerPort;

        attribute nominalVoltage : VoltageValue = 9 [V];
        attribute maxOutputCurrent : ElectricCurrent = 5 [mA];
        attribute batteryLevel : Real = 100.0;
        attribute batteryCapacity : Real = 500.0;
        attribute isPowerOn : Boolean = false;

        action def SupplyPower {
            in requestedVoltage : VoltageValue;
            out suppliedVoltage : VoltageValue;
            out suppliedCurrent : ElectricCurrent;
            out available : Boolean;
        }

        action def MonitorBattery {
            out level : Real;
            out lowBattery : Boolean;
        }

        perform supplyPower : SupplyPower {
            in requestedVoltage = nominalVoltage;
            out suppliedVoltage = nominalVoltage;
        }

        perform monitorBattery : MonitorBattery;

        assert constraint {
            batteryLevel >= 0.0 and batteryLevel <= 100.0
        }
    }

    part def CurrentRegulator {
        doc /* Precisely manages current to maintain constant therapeutic output */
        port powerIn : ElectricalPowerPort;
        port regulatedOut : ElectricalPowerPort;
        port controlIn : ControlSignalPort;

        attribute targetCurrent : ElectricCurrent = 3 [mA];
        attribute tolerance : ElectricCurrent = 0.1 [mA];
        attribute actualCurrent : ElectricCurrent;
        attribute minTherapeuticCurrent : ElectricCurrent = 2 [mA];
        attribute maxTherapeuticCurrent : ElectricCurrent = 4 [mA];
        attribute isRegulating : Boolean = false;

        action def RegulateCurrent {
            in inputCurrent : ElectricCurrent;
            in target : ElectricCurrent;
            in toleranceValue : ElectricCurrent;
            out regulatedCurrent : ElectricCurrent;
            out stable : Boolean;
        }

        perform regulateCurrent : RegulateCurrent {
            in target = targetCurrent;
            in toleranceValue = tolerance;
            out regulatedCurrent = actualCurrent;
        }

        assert constraint {
            actualCurrent >= minTherapeuticCurrent and actualCurrent <= maxTherapeuticCurrent
        }
    }

    part def DrugReservoir {
        doc /* Pre-filled reservoir containing ionized therapeutic drug */
        port drugOut : DrugDeliveryPort;

        attribute drug : IonizedDrug {
            attribute charge = 1;
            attribute name = "Dexamethasone Phosphate";
        }
        attribute remainingDose : DrugDosage = 10 [mg];
        attribute initialDose : DrugDosage = 10 [mg];
        attribute isPrefilled : Boolean = true;
        attribute reservoirVolume : Real = 2.0;
        attribute drugConcentration : Real = 5.0;

        action def ReleaseDrug {
            in current : ElectricCurrent;
            in duration : DurationValue;
            out drugReleased : IonizedDrug;
            out doseReleased : DrugDosage;
            out remaining : DrugDosage;
        }

        assert constraint {
            remainingDose >= 0 [mg] and remainingDose <= initialDose
        }
    }

    part def ActiveElectrode {
        doc /* Electrode containing drug reservoir; drives charged drug molecules into skin */
        port electricalConnection : ElectricalPowerPort;
        port skinContact : SkinContactPort;

        part reservoir : DrugReservoir;

        attribute electrodeArea : Real = 5.0;
        attribute contactImpedance : ElectricalImpedance;
        attribute isActive : Boolean = false;

        action def DeliverDrug {
            in current : ElectricCurrent;
            in duration : DurationValue;
            out drugDelivered : IonizedDrug;
            out doseDelivered : DrugDosage;
        }

        perform deliverDrug : DeliverDrug;

        assert constraint {
            electrodeArea > 0.0
        }
    }

    part def ReturnElectrode {
        doc /* Return electrode completing the electrical circuit through patient skin */
        port electricalConnection : ElectricalPowerPort;
        port skinContact : SkinContactPort;

        attribute electrodeArea : Real = 5.0;
        attribute contactImpedance : ElectricalImpedance;
        attribute isActive : Boolean = false;

        action def CompleteCircuit {
            in incomingCurrent : ElectricCurrent;
            out returnCurrent : ElectricCurrent;
        }

        perform completeCircuit : CompleteCircuit;
    }

    part def ImpedanceSensor {
        doc /* Continuously measures skin impedance for contact quality and irritation detection */
        port sensorOut : SensorDataPort;
        port skinContact : SkinContactPort;

        attribute measuredImpedance : ElectricalImpedance;
        attribute samplingRate : Real = 10.0;
        attribute previousImpedance : ElectricalImpedance;
        attribute impedanceDropThreshold : Real = 0.3;
        attribute isCalibrated : Boolean = true;

        action def MeasureImpedance {
            in contactImpedance : ElectricalImpedance;
            out impedanceReading : ElectricalImpedance;
            out contactQuality : Real;
        }

        action def DetectImpedanceDrop {
            in currentReading : ElectricalImpedance;
            in previousReading : ElectricalImpedance;
            out suddenDrop : Boolean;
        }

        perform measureImpedance : MeasureImpedance {
            out impedanceReading = measuredImpedance;
        }

        perform detectImpedanceDrop : DetectImpedanceDrop;
    }

    part def SafetyMonitor {
        doc /* Comprehensive safety monitor checking current, time, and impedance limits */
        port sensorIn : SensorDataPort;
        port controlOut : ControlSignalPort;

        attribute maxSafeCurrent : ElectricCurrent = 4 [mA];
        attribute minSafeCurrent : ElectricCurrent = 2 [mA];
        attribute maxTreatmentTime : DurationValue = 1800 [s];
        attribute minSafeImpedance : ElectricalImpedance = 100 [ohm];
        attribute maxSafeImpedance : ElectricalImpedance = 10000 [ohm];
        attribute maxImpedanceDropRate : Real = 0.5;
        attribute faultDetected : Boolean = false;
        attribute faultType : String;
        attribute accumulatedTime : DurationValue = 0 [s];

        action def MonitorSafety {
            in currentReading : ElectricCurrent;
            in impedanceReading : ElectricalImpedance;
            in elapsedTime : DurationValue;
            out fault : Boolean;
            out faultDescription : String;
        }

        action def CheckCurrentLimit {
            in current : ElectricCurrent;
            out overCurrent : Boolean;
        }

        action def CheckTimeLimit {
            in elapsed : DurationValue;
            out timeExceeded : Boolean;
        }

        action def CheckImpedanceRange {
            in impedance : ElectricalImpedance;
            out impedanceFault : Boolean;
        }

        perform monitorSafety : MonitorSafety {
            out fault = faultDetected;
        }

        perform checkCurrentLimit : CheckCurrentLimit;
        perform checkTimeLimit : CheckTimeLimit;
        perform checkImpedanceRange : CheckImpedanceRange;

        assert constraint {
            maxSafeCurrent > 0 [mA] and maxTreatmentTime > 0 [s]
        }
    }

    part def TreatmentController {
        doc /* Central controller managing treatment state machine and dosage monitoring */
        port controlOut : ControlSignalPort;
        port sensorIn : SensorDataPort;
        port safetyIn : ControlSignalPort;
        port regulatorControl : ControlSignalPort;
        port statusOut : StatusPort;

        attribute targetDosage : DrugDosage = 10 [mg];
        attribute deliveredDosage : DrugDosage = 0 [mg];
        attribute treatmentTime : DurationValue = 0 [s];
        attribute deliveredCurrent : ElectricCurrent;
        attribute skinImpedance : ElectricalImpedance;
        attribute treatmentActive : Boolean = false;
        attribute treatmentProgress : Real = 0.0;
        attribute lastFaultCode : Integer = 0;

        action def CalculateDosage {
            in current : ElectricCurrent;
            in duration : DurationValue;
            in drugConcentration : Real;
            out dosage : DrugDosage;
            out progress : Real;
        }

        action def UpdateTreatmentStatus {
            in currentState : String;
            in progress : Real;
            out status : TreatmentStatus;
        }

        perform calculateDosage : CalculateDosage {
            in current = deliveredCurrent;
            in duration = treatmentTime;
            out dosage = deliveredDosage;
            out progress = treatmentProgress;
        }

        perform updateTreatmentStatus : UpdateTreatmentStatus;

        state machine treatmentBehavior {
            entry; then Idle;

            state Idle {
                entry action {
                    treatmentActive = false;
                    deliveredDosage = 0 [mg];
                    treatmentTime = 0 [s];
                    treatmentProgress = 0.0;
                    controlOut.command = "idle";
                }
            }

            transition from Idle to Preparation
                when controlOut.command == "start";

            state Preparation {
                entry action {
                    controlOut.command = "prepare";
                    regulatorControl.command = "standby";
                }

                do action {
                    skinImpedance = sensorIn.impedance;
                }
            }

            transition from Preparation to ActiveDelivery
                when sensorIn.impedance >= 100 [ohm] and sensorIn.impedance <= 10000 [ohm];

            transition from Preparation to Fault
                when sensorIn.impedance < 100 [ohm] or sensorIn.impedance > 10000 [ohm];

            state ActiveDelivery {
                entry action {
                    treatmentActive = true;
                    controlOut.command = "deliver";
                    regulatorControl.command = "activate";
                }

                do action {
                    deliveredCurrent = sensorIn.currentReading;
                    treatmentTime = sensorIn.elapsedTime;
                    skinImpedance = sensorIn.impedance;
                    treatmentProgress = deliveredDosage / targetDosage;
                }
            }

            transition from ActiveDelivery to Complete
                when deliveredDosage >= targetDosage;

            transition from ActiveDelivery to Fault
                when safetyIn.feedback == "fault";

            state Complete {
                entry action {
                    treatmentActive = false;
                    controlOut.command = "complete";
                    regulatorControl.command = "deactivate";
                    statusOut.status.state = "complete";
                    statusOut.status.progress = 1.0;
                }

                exit action {
                    deliveredDosage = 0 [mg];
                    treatmentTime = 0 [s];
                }
            }

            state Fault {
                entry action {
                    treatmentActive = false;
                    controlOut.command = "terminate";
                    regulatorControl.command = "emergency_stop";
                    statusOut.status.state = "fault";
                    lastFaultCode = 1;
                }

                do action {
                    safetyIn.feedback = "acknowledged";
                }
            }

            transition from Complete to Idle
                when controlOut.command == "reset";

            transition from Fault to Idle
                when controlOut.command == "reset";
        }
    }

    part def StatusIndicator {
        doc /* Visual and audible indicator for treatment status and alerts */
        port statusIn : StatusPort;

        attribute displayState : String = "off";
        attribute ledColor : String;
        attribute buzzerActive : Boolean = false;

        action def UpdateDisplay {
            in status : TreatmentStatus;
            out displayText : String;
            out ledColorValue : String;
            out buzzer : Boolean;
        }

        perform updateDisplay : UpdateDisplay;
    }

    // ===== Requirements =====

    requirement def SafeTherapeuticCurrent {
        doc /* Device shall maintain current within safe therapeutic range of 2-4 mA during active delivery */
        attribute minCurrent : ElectricCurrent = 2 [mA];
        attribute maxCurrent : ElectricCurrent = 4 [mA];
        require constraint {
            deliveredCurrent >= minCurrent and deliveredCurrent <= maxCurrent
        }
    }

    requirement def TreatmentTimeLimit {
        doc /* Total treatment time shall not exceed 1800 seconds */
        attribute maxDuration : DurationValue = 1800 [s];
        require constraint {
            totalTreatmentTime <= maxDuration
        }
    }

    requirement def ImpedanceSafetyRange {
        doc /* Skin impedance shall remain within 100-10000 ohm during treatment */
        attribute minImpedance : ElectricalImpedance = 100 [ohm];
        attribute maxImpedance : ElectricalImpedance = 10000 [ohm];
        require constraint {
            skinImpedance >= minImpedance and skinImpedance <= maxImpedance
        }
    }

    requirement def TargetDosageDelivery {
        doc /* Device shall deliver the prescribed target dosage of 10 mg */
        attribute targetDose : DrugDosage = 10 [mg];
        require constraint {
            deliveredDose >= targetDose
        }
    }

    requirement def FaultTermination {
        doc /* Upon detecting unsafe conditions, device shall immediately terminate treatment and enter fault state */
        require constraint {
            faultDetected implies currentTerminated
        }
    }

    requirement def ImpedanceDropDetection {
        doc /* System shall detect sudden impedance drops indicating potential skin irritation */
        attribute dropThreshold : Real = 0.3;
        require constraint {
            suddenImpedanceDrop implies faultDetected
        }
    }

    requirement def NonInvasiveDelivery {
        doc /* Drug delivery shall be non-invasive using iontophoretic current through intact skin */
        require constraint {
            deliveryMethod == "iontophoretic" and injectionsRequired == false
        }
    }

    requirement def PrefilledReservoir {
        doc /* Active electrode shall contain a pre-filled drug reservoir */
        require constraint {
            reservoirIsPrefilled == true
        }
    }

    // ===== Top-level System =====

    part def IontophoreticDevice {
        doc /* Portable iontophoretic drug delivery system for non-invasive transdermal medication delivery using controlled electric current */

        port patientInterface : SkinContactPort;
        port userInterface : ControlSignalPort;

        requirement safeCurrentReq : SafeTherapeuticCurrent;
        requirement timeLimitReq : TreatmentTimeLimit;
        requirement impedanceReq : ImpedanceSafetyRange;
        requirement dosageReq : TargetDosageDelivery;
        requirement faultTermReq : FaultTermination;
        requirement impedanceDropReq : ImpedanceDropDetection;
        requirement nonInvasiveReq : NonInvasiveDelivery;
        requirement prefilledReq : PrefilledReservoir;

        part controller : TreatmentController;
        part powerSupply : PowerSupply;
        part currentRegulator : CurrentRegulator;
        part activeElectrode : ActiveElectrode;
        part returnElectrode : ReturnElectrode;
        part impedanceSensor : ImpedanceSensor;
        part safetyMonitor : SafetyMonitor;
        part statusIndicator : StatusIndicator;

        // Power supply to current regulator
        connection from powerSupply.powerOut to currentRegulator.powerIn;

        // Current regulator to active electrode
        connection from currentRegulator.regulatedOut to activeElectrode.electricalConnection;

        // Return electrode back to power supply (completing circuit)
        connection from returnElectrode.electricalConnection to powerSupply.returnIn;

        // Active electrode to patient skin interface
        connection from activeElectrode.skinContact to patientInterface;

        // Patient skin interface to return electrode
        connection from patientInterface to returnElectrode.skinContact;

        // Impedance sensor to treatment controller
        connection from impedanceSensor.sensorOut to controller.sensorIn;

        // Impedance sensor to safety monitor
        connection from impedanceSensor.sensorOut to safetyMonitor.sensorIn;

        // Safety monitor to treatment controller
        connection from safetyMonitor.controlOut to controller.safetyIn;

        // Treatment controller to current regulator
        connection from controller.regulatorControl to currentRegulator.controlIn;

        // Treatment controller to status indicator
        connection from controller.statusOut to statusIndicator.statusIn;

        // Treatment controller to user interface
        connection from controller.controlOut to userInterface;

        // Requirement satisfaction
        satisfy safeCurrentReq by currentRegulator;
        satisfy timeLimitReq by safetyMonitor;
        satisfy impedanceReq by impedanceSensor;
        satisfy dosageReq by controller;
        satisfy faultTermReq by controller;
        satisfy impedanceDropReq by safetyMonitor;
        satisfy nonInvasiveReq by IontophoreticDevice;
        satisfy prefilledReq by activeElectrode.reservoir;
    }
}
