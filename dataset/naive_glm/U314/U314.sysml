package MAST_System {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    def def PressureValue :> Real { unit mmHg; }
    def def BloodPressureValue :> Real { unit mmHg; }
    def def HeartRateValue :> Real { unit bpm; }
    def def PerfusionIndexValue :> Real { unit 'percent'; }
    def def FlowRateValue :> Real { unit 'L/min'; }
    def def DurationValue :> Real { unit s; }
    def def VolumeValue :> Real { unit L; }

    item def PhysiologicalSignal {
        attribute systolicBP : BloodPressureValue;
        attribute diastolicBP : BloodPressureValue;
        attribute meanArterialPressure : BloodPressureValue;
        attribute heartRate : HeartRateValue;
        attribute perfusionIndex : PerfusionIndexValue;
    }

    enum def ShockSeverity {
        none = 0;
        mild = 1;
        moderate = 2;
        severe = 3;
    }

    enum def TherapyPhase {
        assessment;
        deployment;
        maintenance;
        weaning;
        emergencyDeflation;
        standby;
    }

    item def PressureReading {
        attribute compartmentId : String;
        attribute measuredPressure : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def ControllerCommand {
        attribute targetCompartment : String;
        attribute targetPressure : PressureValue;
        attribute commandType : String;
    }

    // ===== Requirements =====
    requirement def StabilizePatientRequirement {
        doc "The MAST system shall stabilize a patient in hemorrhagic shock by applying graduated external pressure to the lower body."
        objective {
            subject patientStability : Patient;
            predicate patientStability.meanArterialPressure >= 65.0 [mmHg]
        }
    }

    requirement def SequentialInflationRequirement {
        doc "The system shall inflate leg compartments first, re-evaluate vitals, then inflate abdominal compartment only if blood pressure remains insufficient."
        constraint {
            subject legInflation : InflatableCompartment;
            subject abdomenInflation : InflatableCompartment;
            predicate legInflation.inflationComplete implies (abdomenInflation.inflationInitiated implies legInflation.targetPressureAchieved)
        }
    }

    requirement def MaxPressureLimitRequirement {
        doc "No compartment shall exceed the maximum safe pressure of 104 mmHg to prevent tissue injury."
        constraint {
            subject compartment : InflatableCompartment;
            predicate compartment.currentPressure <= 104.0 [mmHg]
        }
    }

    requirement def EmergencyDeflationRequirement {
        doc "The system shall provide emergency rapid deflation of all compartments within 10 seconds."
        constraint {
            subject deflationTime : DurationValue;
            predicate deflationTime <= 10.0 [s]
        }
    }

    requirement def GradualWeaningRequirement {
        doc "The weaning phase shall gradually release pressure at no more than 5 mmHg per minute to prevent sudden hypotension."
        constraint {
            subject releaseRate : PressureValue;
            predicate releaseRate <= 5.0 [mmHg/min]
        }
    }

    requirement def ContinuousMonitoringRequirement {
        doc "The system shall continuously receive patient vital signs throughout all therapy phases."
        constraint {
            subject monitoring : PatientMonitoringUnit;
            predicate monitoring.samplingRate >= 1.0 [Hz]
        }
    }

    // ===== Port Definitions =====
    port def PressureOutputPort {
        out pressureReading : PressureReading;
    }

    port def PressureInputPort {
        in pressureReading : PressureReading;
    }

    port def CommandOutputPort {
        out command : ControllerCommand;
    }

    port def CommandInputPort {
        in command : ControllerCommand;
    }

    port def VitalSignsOutputPort {
        out vitals : PhysiologicalSignal;
    }

    port def VitalSignsInputPort {
        in vitals : PhysiologicalSignal;
    }

    port def PneumaticOutputPort {
        out airPressure : PressureValue;
        out airFlow : FlowRateValue;
    }

    port def PneumaticInputPort {
        in airPressure : PressureValue;
        in airFlow : FlowRateValue;
    }

    // ===== Part Definitions =====
    part def Patient {
        attribute meanArterialPressure : BloodPressureValue;
        attribute heartRate : HeartRateValue;
        attribute perfusionIndex : PerfusionIndexValue;
        attribute shockSeverity : ShockSeverity;
    }

    part def InflatableCompartment {
        attribute compartmentId : String;
        attribute targetPressure : PressureValue;
        attribute currentPressure : PressureValue := 0.0 [mmHg];
        attribute maxSafePressure : PressureValue := 104.0 [mmHg];
        attribute inflationComplete : Boolean := false;
        attribute targetPressureAchieved : Boolean := false;
        attribute inflationInitiated : Boolean := false;

        port pressureOutput : PressureOutputPort;
        port pneumaticInput : PneumaticInputPort;

        exhibit state def CompartmentBehavior {
            entry action { currentPressure = 0.0 [mmHg]; }

            state Deflated {
                entry action { currentPressure = 0.0 [mmHg]; inflationComplete = false; }
            }

            state Inflating {
                entry action { inflationInitiated = true; }
                do action {
                    if currentPressure < targetPressure then {
                        currentPressure = currentPressure + 2.0 [mmHg];
                    }
                    if currentPressure >= targetPressure then {
                        targetPressureAchieved = true;
                        inflationComplete = true;
                    }
                }
            }

            state Maintaining {
                do action {
                    if currentPressure > targetPressure then {
                        currentPressure = currentPressure - 0.5 [mmHg];
                    }
                    if currentPressure < targetPressure then {
                        currentPressure = currentPressure + 0.5 [mmHg];
                    }
                }
            }

            state Weaning {
                do action {
                    if currentPressure > 0.0 [mmHg] then {
                        currentPressure = currentPressure - 0.083 [mmHg];
                    }
                }
            }

            state RapidDeflating {
                entry action { currentPressure = 0.0 [mmHg]; inflationComplete = false; }
            }

            transition from Deflated to Inflating when pneumaticInput.airPressure > 0.0 [mmHg];
            transition from Inflating to Maintaining when currentPressure >= targetPressure;
            transition from Maintaining to Weaning when inflationComplete;
            transition from Weaning to Deflated when currentPressure <= 0.0 [mmHg];
            transition from Inflating to RapidDeflating when currentPressure > maxSafePressure;
            transition from Maintaining to RapidDeflating when currentPressure > maxSafePressure;
            transition from Weaning to RapidDeflating when currentPressure > maxSafePressure;
            transition from RapidDeflating to Deflated;
        }
    }

    part def PressureSensor {
        attribute sensorId : String;
        attribute measuredPressure : PressureValue;
        attribute samplingRate : Real := 10.0 [Hz];

        port pressureOutput : PressureOutputPort;

        exhibit state def SensorBehavior {
            state Active {
                do action {
                    pressureOutput.pressureReading.measuredPressure = measuredPressure;
                    pressureOutput.pressureReading.compartmentId = sensorId;
                }
            }
            state Fault {
                entry action { pressureOutput.pressureReading.measuredPressure = -1.0 [mmHg]; }
            }
            transition from Active to Fault when measuredPressure < 0.0 [mmHg];
            transition from Fault to Active when measuredPressure >= 0.0 [mmHg];
        }
    }

    part def PatientMonitoringUnit {
        attribute samplingRate : Real := 1.0 [Hz];
        attribute currentVitals : PhysiologicalSignal;

        port vitalsOutput : VitalSignsOutputPort;

        exhibit state def MonitoringBehavior {
            state Monitoring {
                do action {
                    vitalsOutput.vitals.systolicBP = currentVitals.systolicBP;
                    vitalsOutput.vitals.diastolicBP = currentVitals.diastolicBP;
                    vitalsOutput.vitals.meanArterialPressure = currentVitals.meanArterialPressure;
                    vitalsOutput.vitals.heartRate = currentVitals.heartRate;
                    vitalsOutput.vitals.perfusionIndex = currentVitals.perfusionIndex;
                }
            }
            state SensorFault {
                entry action { vitalsOutput.vitals.meanArterialPressure = -1.0 [mmHg]; }
            }
            transition from Monitoring to SensorFault when currentVitals.meanArterialPressure < 0.0 [mmHg];
            transition from SensorFault to Monitoring when currentVitals.meanArterialPressure >= 0.0 [mmHg];
        }
    }

    part def PneumaticControlUnit {
        attribute pumpActive : Boolean := false;
        attribute pumpFlowRate : FlowRateValue := 5.0 [L/min];
        attribute maxOutputPressure : PressureValue := 120.0 [mmHg];
        attribute valveOpen : Boolean := false;

        port commandInput : CommandInputPort;
        port pneumaticOutputLeftLeg : PneumaticOutputPort;
        port pneumaticOutputRightLeg : PneumaticOutputPort;
        port pneumaticOutputAbdomen : PneumaticOutputPort;

        exhibit state def PneumaticBehavior {
            state Idle {
                entry action { pumpActive = false; valveOpen = false; }
            }

            state PumpingLeftLeg {
                entry action { pumpActive = true; }
                do action {
                    pneumaticOutputLeftLeg.airPressure = maxOutputPressure;
                    pneumaticOutputLeftLeg.airFlow = pumpFlowRate;
                }
            }

            state PumpingRightLeg {
                entry action { pumpActive = true; }
                do action {
                    pneumaticOutputRightLeg.airPressure = maxOutputPressure;
                    pneumaticOutputRightLeg.airFlow = pumpFlowRate;
                }
            }

            state PumpingAbdomen {
                entry action { pumpActive = true; }
                do action {
                    pneumaticOutputAbdomen.airPressure = maxOutputPressure;
                    pneumaticOutputAbdomen.airFlow = pumpFlowRate;
                }
            }

            state Holding {
                entry action { pumpActive = false; }
                do action {
                    pneumaticOutputLeftLeg.airPressure = 0.0 [mmHg];
                    pneumaticOutputLeftLeg.airFlow = 0.0 [L/min];
                    pneumaticOutputRightLeg.airPressure = 0.0 [mmHg];
                    pneumaticOutputRightLeg.airFlow = 0.0 [L/min];
                    pneumaticOutputAbdomen.airPressure = 0.0 [mmHg];
                    pneumaticOutputAbdomen.airFlow = 0.0 [L/min];
                }
            }

            state RapidDeflation {
                entry action { pumpActive = false; valveOpen = true; }
                do action {
                    pneumaticOutputLeftLeg.airPressure = 0.0 [mmHg];
                    pneumaticOutputLeftLeg.airFlow = -10.0 [L/min];
                    pneumaticOutputRightLeg.airPressure = 0.0 [mmHg];
                    pneumaticOutputRightLeg.airFlow = -10.0 [L/min];
                    pneumaticOutputAbdomen.airPressure = 0.0 [mmHg];
                    pneumaticOutputAbdomen.airFlow = -10.0 [L/min];
                }
            }

            transition from Idle to PumpingLeftLeg when commandInput.command.targetCompartment == "leftLeg" and commandInput.command.commandType == "inflate";
            transition from PumpingLeftLeg to PumpingRightLeg when commandInput.command.targetCompartment == "rightLeg" and commandInput.command.commandType == "inflate";
            transition from PumpingRightLeg to Holding when commandInput.command.commandType == "hold";
            transition from Holding to PumpingAbdomen when commandInput.command.targetCompartment == "abdomen" and commandInput.command.commandType == "inflate";
            transition from PumpingAbdomen to Holding when commandInput.command.commandType == "hold";
            transition from Holding to RapidDeflation when commandInput.command.commandType == "emergencyDeflate";
            transition from PumpingLeftLeg to RapidDeflation when commandInput.command.commandType == "emergencyDeflate";
            transition from PumpingRightLeg to RapidDeflation when commandInput.command.commandType == "emergencyDeflate";
            transition from PumpingAbdomen to RapidDeflation when commandInput.command.commandType == "emergencyDeflate";
            transition from RapidDeflation to Idle when commandInput.command.commandType == "reset";
        }
    }

    part def TherapyController {
        attribute currentPhase : TherapyPhase := TherapyPhase::standby;
        attribute detectedShockSeverity : ShockSeverity := ShockSeverity::none;
        attribute legTargetPressure : PressureValue := 40.0 [mmHg];
        attribute abdomenTargetPressure : PressureValue := 60.0 [mmHg];
        attribute maxLegPressure : PressureValue := 104.0 [mmHg];
        attribute maxAbdomenPressure : PressureValue := 104.0 [mmHg];
        attribute bpImprovementThreshold : BloodPressureValue := 65.0 [mmHg];
        attribute weaningRate : PressureValue := 5.0 [mmHg/min];
        attribute lastVitals : PhysiologicalSignal;
        attribute legsInflated : Boolean := false;
        attribute abdomenInflated : Boolean := false;
        attribute patientStable : Boolean := false;

        port vitalsInput : VitalSignsInputPort;
        port pressureInputLeftLeg : PressureInputPort;
        port pressureInputRightLeg : PressureInputPort;
        port pressureInputAbdomen : PressureInputPort;
        port commandOutput : CommandOutputPort;

        exhibit state def ControllerBehavior {
            entry action { currentPhase = TherapyPhase::assessment; }

            state Assessment {
                do action {
                    lastVitals = vitalsInput.vitals;
                    if lastVitals.meanArterialPressure < 65.0 [mmHg] and lastVitals.heartRate > 100.0 [bpm] then {
                        if lastVitals.meanArterialPressure < 50.0 [mmHg] then {
                            detectedShockSeverity = ShockSeverity::severe;
                        } else if lastVitals.meanArterialPressure < 60.0 [mmHg] then {
                            detectedShockSeverity = ShockSeverity::moderate;
                        } else {
                            detectedShockSeverity = ShockSeverity::mild;
                        }
                    } else {
                        detectedShockSeverity = ShockSeverity::none;
                    }
                }
            }

            state DeployLegs {
                entry action {
                    commandOutput.command.targetCompartment = "leftLeg";
                    commandOutput.command.targetPressure = legTargetPressure;
                    commandOutput.command.commandType = "inflate";
                }
                do action {
                    if pressureInputLeftLeg.pressureReading.measuredPressure >= legTargetPressure then {
                        commandOutput.command.targetCompartment = "rightLeg";
                        commandOutput.command.targetPressure = legTargetPressure;
                        commandOutput.command.commandType = "inflate";
                    }
                    if pressureInputRightLeg.pressureReading.measuredPressure >= legTargetPressure then {
                        legsInflated = true;
                        commandOutput.command.commandType = "hold";
                    }
                }
            }

            state ReevaluateAfterLegs {
                do action {
                    lastVitals = vitalsInput.vitals;
                    if lastVitals.meanArterialPressure < bpImprovementThreshold then {
                        // BP insufficient, proceed to abdomen inflation
                    } else {
                        patientStable = true;
                    }
                }
            }

            state DeployAbdomen {
                entry action {
                    commandOutput.command.targetCompartment = "abdomen";
                    commandOutput.command.targetPressure = abdomenTargetPressure;
                    commandOutput.command.commandType = "inflate";
                }
                do action {
                    if pressureInputAbdomen.pressureReading.measuredPressure >= abdomenTargetPressure then {
                        abdomenInflated = true;
                        commandOutput.command.commandType = "hold";
                    }
                }
            }

            state Maintenance {
                do action {
                    lastVitals = vitalsInput.vitals;
                    if pressureInputLeftLeg.pressureReading.measuredPressure > maxLegPressure then {
                        commandOutput.command.commandType = "emergencyDeflate";
                    }
                    if pressureInputRightLeg.pressureReading.measuredPressure > maxLegPressure then {
                        commandOutput.command.commandType = "emergencyDeflate";
                    }
                    if pressureInputAbdomen.pressureReading.measuredPressure > maxAbdomenPressure then {
                        commandOutput.command.commandType = "emergencyDeflate";
                    }
                    if lastVitals.meanArterialPressure >= 70.0 [mmHg] and lastVitals.heartRate < 100.0 [bpm] then {
                        patientStable = true;
                    }
                }
            }

            state Weaning {
                entry action {
                    commandOutput.command.commandType = "wean";
                }
                do action {
                    if pressureInputLeftLeg.pressureReading.measuredPressure > 0.0 [mmHg] then {
                        legTargetPressure = legTargetPressure - weaningRate / 60.0 [mmHg];
                    }
                    if pressureInputAbdomen.pressureReading.measuredPressure > 0.0 [mmHg] then {
                        abdomenTargetPressure = abdomenTargetPressure - weaningRate / 60.0 [mmHg];
                    }
                    if pressureInputLeftLeg.pressureReading.measuredPressure <= 0.0 [mmHg] and pressureInputRightLeg.pressureReading.measuredPressure <= 0.0 [mmHg] and pressureInputAbdomen.pressureReading.measuredPressure <= 0.0 [mmHg] then {
                        patientStable = true;
                    }
                }
            }

            state EmergencyDeflation {
                entry action {
                    commandOutput.command.commandType = "emergencyDeflate";
                }
                do action {
                    commandOutput.command.commandType = "reset";
                }
            }

            state Standby {
                entry action { currentPhase = TherapyPhase::standby; }
            }

            transition from Assessment to DeployLegs when detectedShockSeverity != ShockSeverity::none;
            transition from Assessment to Standby when detectedShockSeverity == ShockSeverity::none;
            transition from DeployLegs to ReevaluateAfterLegs when legsInflated == true;
            transition from ReevaluateAfterLegs to DeployAbdomen when lastVitals.meanArterialPressure < bpImprovementThreshold;
            transition from ReevaluateAfterLegs to Maintenance when lastVitals.meanArterialPressure >= bpImprovementThreshold;
            transition from DeployAbdomen to Maintenance when abdomenInflated == true;
            transition from Maintenance to Weaning when patientStable == true;
            transition from Maintenance to EmergencyDeflation when pressureInputLeftLeg.pressureReading.measuredPressure > maxLegPressure or pressureInputRightLeg.pressureReading.measuredPressure > maxLegPressure or pressureInputAbdomen.pressureReading.measuredPressure > maxAbdomenPressure;
            transition from Weaning to Standby when pressureInputLeftLeg.pressureReading.measuredPressure <= 0.0 [mmHg] and pressureInputRightLeg.pressureReading.measuredPressure <= 0.0 [mmHg] and pressureInputAbdomen.pressureReading.measuredPressure <= 0.0 [mmHg];
            transition from EmergencyDeflation to Standby when commandInput.command.commandType == "reset";
        }
    }

    // ===== Top-level System =====
    part def MASTSystem {
        satisfy StabilizePatientRequirement;
        satisfy SequentialInflationRequirement;
        satisfy MaxPressureLimitRequirement;
        satisfy EmergencyDeflationRequirement;
        satisfy GradualWeaningRequirement;
        satisfy ContinuousMonitoringRequirement;

        part patient : Patient;

        part therapyController : TherapyController {
            port vitalsInput : VitalSignsInputPort;
            port pressureInputLeftLeg : PressureInputPort;
            port pressureInputRightLeg : PressureInputPort;
            port pressureInputAbdomen : PressureInputPort;
            port commandOutput : CommandOutputPort;
        }

        part patientMonitoringUnit : PatientMonitoringUnit {
            port vitalsOutput : VitalSignsOutputPort;
        }

        part pneumaticControlUnit : PneumaticControlUnit {
            port commandInput : CommandInputPort;
            port pneumaticOutputLeftLeg : PneumaticOutputPort;
            port pneumaticOutputRightLeg : PneumaticOutputPort;
            port pneumaticOutputAbdomen : PneumaticOutputPort;
        }

        part leftLegCompartment : InflatableCompartment {
            attribute compartmentId := "leftLeg";
            attribute targetPressure := 40.0 [mmHg];
            port pressureOutput : PressureOutputPort;
            port pneumaticInput : PneumaticInputPort;
        }

        part rightLegCompartment : InflatableCompartment {
            attribute compartmentId := "rightLeg";
            attribute targetPressure := 40.0 [mmHg];
            port pressureOutput : PressureOutputPort;
            port pneumaticInput : PneumaticInputPort;
        }

        part abdomenCompartment : InflatableCompartment {
            attribute compartmentId := "abdomen";
            attribute targetPressure := 60.0 [mmHg];
            port pressureOutput : PressureOutputPort;
            port pneumaticInput : PneumaticInputPort;
        }

        part leftLegPressureSensor : PressureSensor {
            attribute sensorId := "leftLegSensor";
            port pressureOutput : PressureOutputPort;
        }

        part rightLegPressureSensor : PressureSensor {
            attribute sensorId := "rightLegSensor";
            port pressureOutput : PressureOutputPort;
        }

        part abdomenPressureSensor : PressureSensor {
            attribute sensorId := "abdomenSensor";
            port pressureOutput : PressureOutputPort;
        }

        // Connections
        connection vitalsFlow connect patientMonitoringUnit.vitalsOutput to therapyController.vitalsInput;

        connection leftLegPressureFeedback connect leftLegPressureSensor.pressureOutput to therapyController.pressureInputLeftLeg;
        connection rightLegPressureFeedback connect rightLegPressureSensor.pressureOutput to therapyController.pressureInputRightLeg;
        connection abdomenPressureFeedback connect abdomenPressureSensor.pressureOutput to therapyController.pressureInputAbdomen;

        connection leftLegCompartmentFeedback connect leftLegCompartment.pressureOutput to leftLegPressureSensor.pressureOutput;
        connection rightLegCompartmentFeedback connect rightLegCompartment.pressureOutput to rightLegPressureSensor.pressureOutput;
        connection abdomenCompartmentFeedback connect abdomenCompartment.pressureOutput to abdomenPressureSensor.pressureOutput;

        connection controllerToPump connect therapyController.commandOutput to pneumaticControlUnit.commandInput;

        connection pumpToLeftLeg connect pneumaticControlUnit.pneumaticOutputLeftLeg to leftLegCompartment.pneumaticInput;
        connection pumpToRightLeg connect pneumaticControlUnit.pneumaticOutputRightLeg to rightLegCompartment.pneumaticInput;
        connection pumpToAbdomen connect pneumaticControlUnit.pneumaticOutputAbdomen to abdomenCompartment.pneumaticInput;
    }
}
