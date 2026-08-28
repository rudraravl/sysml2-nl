package BarographSystem {

    import SI::*;

    // ============================================================
    // Derived units
    // ============================================================
    value def hPa = 100 * Pa;
    value def mm = 0.001 * m;
    value def d = 86400 * s;
    value def rev = 1;
    value def deg = 1;

    // ============================================================
    // Value types
    // ============================================================
    value def PressureValue = Real { unit: hPa; }
    value def LengthValue = Real { unit: mm; }
    value def DurationValue = Real { unit: d; }
    value def RotationalSpeedValue = Real { unit: rev/d; }
    value def ForceValue = Real { unit: N; }
    value def TorqueValue = Real { unit: N*m; }
    value def AngleValue = Real { unit: deg; }

    // ============================================================
    // Item definitions
    // ============================================================
    item def AmbientAir {
        attribute pressure : PressureValue;
        attribute temperature : Real;
        attribute humidity : Real;
    }

    item def Ink {
        attribute color : String;
        attribute viscosity : Real;
        attribute volume : LengthValue;
    }

    item def BarogramTrace {
        attribute pressureSamples : List<PressureValue>;
        attribute timeMarks : List<Real>;
        attribute startDate : String;
        attribute endDate : String;
    }

    // ============================================================
    // Port definitions
    // ============================================================
    port def PressurePort {
        in attribute pressure : PressureValue;
    }

    port def DisplacementPort {
        out attribute displacement : LengthValue;
        in attribute reactionForce : ForceValue;
    }

    port def RotationalMotionPort {
        out attribute angularPosition : AngleValue;
        out attribute angularSpeed : RotationalSpeedValue;
    }

    port def TorquePort {
        out attribute torque : TorqueValue;
    }

    // ============================================================
    // Part definitions
    // ============================================================
    part def AneroidCapsule {
        attribute referencePressure : PressureValue = 1013.25;
        attribute sensitivity : Real = 0.02;
        attribute currentDisplacement : LengthValue = 0.0;
        attribute capsuleDiameter : LengthValue = 60.0;
        attribute numberOfCapsules : Integer = 4;
        attribute isSealed : Boolean = true;
        attribute maxDisplacement : LengthValue = 2.0;

        port pressurePort : PressurePort;
        port displacementPort : DisplacementPort;

        action def respondToPressure {
            in pressure : PressureValue;
            out displacement : LengthValue;
            assign displacement := (pressure - referencePressure) * sensitivity * numberOfCapsules;
        }

        action def update {
            attribute rawDisplacement : LengthValue;
            assign rawDisplacement := (pressurePort.pressure - referencePressure) * sensitivity * numberOfCapsules;
            assign currentDisplacement := rawDisplacement;
            assign displacementPort.displacement := rawDisplacement;
        }
    }

    part def MechanicalLinkage {
        attribute amplificationRatio : Real = 50.0;
        attribute leverCount : Integer = 3;
        attribute backlash : LengthValue = 0.01;
        attribute pinDiameter : LengthValue = 1.0;
        attribute material : String = "brass";

        port inputPort : DisplacementPort;
        port outputPort : DisplacementPort;

        action def amplify {
            in inputDisplacement : LengthValue;
            out outputDisplacement : LengthValue;
            assign outputDisplacement := inputDisplacement * amplificationRatio - backlash;
        }

        action def transfer {
            assign outputPort.displacement := inputPort.displacement * amplificationRatio - backlash;
        }
    }

    part def InkPen {
        attribute inkColor : String = "blue";
        attribute inkLevel : LengthValue = 10.0;
        attribute isClogged : Boolean = false;
        attribute nibWidth : LengthValue = 0.3;
        attribute flowRate : Real = 0.001;

        action def depositInk {
            in position : LengthValue;
            in time : Real;
            assign inkLevel := inkLevel - flowRate;
        }

        action def clearClog {
            assign isClogged := false;
        }

        action def refillInk {
            assign inkLevel := 10.0;
        }
    }

    part def RecordingArm {
        attribute armLength : LengthValue = 300.0;
        attribute penPosition : LengthValue = 0.0;
        attribute material : String = "aluminum";
        attribute pivotAngle : AngleValue = 0.0;
        attribute maxVerticalTravel : LengthValue = 80.0;

        port inputPort : DisplacementPort;

        part pen : InkPen;

        action def move {
            in displacement : LengthValue;
            assign penPosition := displacement;
        }

        action def positionPen {
            in time : Real;
            perform pen.depositInk(position := penPosition, time := time);
        }

        action def update {
            assign penPosition := inputPort.displacement;
        }
    }

    part def ChartPaper {
        attribute height : LengthValue = 80.0;
        attribute width : LengthValue = 314.0;
        attribute timeScaleMin : Real = 0.0;
        attribute timeScaleMax : DurationValue = 7.0;
        attribute pressureScaleMin : PressureValue = 950.0;
        attribute pressureScaleMax : PressureValue = 1050.0;
        attribute isFull : Boolean = false;
        attribute recordedSamples : Integer = 0;
        attribute gridLineSpacing : LengthValue = 10.0;
        attribute timeMarksPerDay : Integer = 24;

        action def recordSample {
            in time : Real;
            in pressure : PressureValue;
            assign recordedSamples := recordedSamples + 1;
            assign isFull := recordedSamples >= (timeMarksPerDay * 7);
        }

        action def reset {
            assign recordedSamples := 0;
            assign isFull := false;
        }

        action def replace {
            perform reset();
            assign isFull := false;
        }
    }

    part def ClockworkDrum {
        attribute radius : LengthValue = 50.0;
        attribute circumference : LengthValue = 314.0;
        attribute angularPosition : AngleValue = 0.0;
        attribute rotationPeriod : DurationValue = 7.0;
        attribute angularSpeed : RotationalSpeedValue = 1.0 / 7.0;
        attribute isRotating : Boolean = false;
        attribute revolutionCount : Integer = 0;
        attribute driveType : String = "spring";

        port rotationPort : RotationalMotionPort;
        part chartPaper : ChartPaper;

        action def startRotation {
            assign isRotating := true;
        }

        action def stopRotation {
            assign isRotating := false;
        }

        action def step {
            attribute deltaAngle : AngleValue;
            assign deltaAngle := angularSpeed * 360.0;
            assign angularPosition := (angularPosition + deltaAngle) mod 360.0;
            assign rotationPort.angularPosition := angularPosition;
            assign rotationPort.angularSpeed := angularSpeed;
        }

        action def completeRevolution {
            assign revolutionCount := revolutionCount + 1;
        }
    }

    part def ClockworkMechanism {
        attribute springTorque : TorqueValue = 0.5;
        attribute isWound : Boolean = true;
        attribute windingPeriod : DurationValue = 7.0;
        attribute gearRatio : Real = 1000.0;
        attribute regulatorType : String = "escapement";

        port torquePort : TorquePort;

        action def releaseEnergy {
            out torque : TorqueValue;
            assign torque := springTorque * gearRatio;
            assign torquePort.torque := torque;
        }

        action def wind {
            assign isWound := true;
            assign springTorque := 0.5;
        }

        action def step {
            perform releaseEnergy();
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def PressureRecordingRequirement {
        doc /* The barograph shall continuously record atmospheric pressure on calibrated chart paper over a 7-day period, producing a continuous pressure-versus-time trace. */;
        subject barograph : Barograph;
    }

    requirement def SevenDayRotationRequirement {
        doc /* The clockwork drum shall complete exactly one full rotation over a seven-day period at a constant slow angular speed. */;
        subject drum : ClockworkDrum;
        attribute targetRotationPeriod : DurationValue = 7.0;
    }

    requirement def AmplificationRequirement {
        doc /* The mechanical linkage shall amplify the aneroid capsule displacement by at least 50 times to drive the recording arm. */;
        subject linkage : MechanicalLinkage;
        attribute minAmplification : Real = 50.0;
    }

    requirement def OperationalStateRequirement {
        doc /* The barograph shall be in one of three states: idle, recording, or maintenance. It shall transition from idle to recording when chart paper is loaded, from recording to maintenance when chart paper is full, and from maintenance to idle when paper replacement is complete. */;
        subject barograph : Barograph;
    }

    requirement def AneroidSensitivityRequirement {
        doc /* The aneroid capsule assembly shall physically expand or contract in proportion to atmospheric pressure changes within a 950 to 1050 hPa operating range. */;
        subject capsule : AneroidCapsule;
        attribute minPressure : PressureValue = 950.0;
        attribute maxPressure : PressureValue = 1050.0;
    }

    // ============================================================
    // Top-level Barograph part
    // ============================================================
    part def Barograph {
        port ambientPressureInput : PressurePort;
        attribute chartLoaded : Boolean = false;
        attribute maintenanceDone : Boolean = false;
        attribute operatingState : String = "idle";
        attribute instrumentName : String = "Aneroid Barograph";
        attribute manufacturer : String = "Meteorological Instruments Ltd.";

        part aneroidCapsule : AneroidCapsule;
        part linkage : MechanicalLinkage;
        part recordingArm : RecordingArm;
        part drum : ClockworkDrum;
        part clockwork : ClockworkMechanism;

        // Connections
        connect ambientPressureInput to aneroidCapsule.pressurePort;
        connect aneroidCapsule.displacementPort to linkage.inputPort;
        connect linkage.outputPort to recordingArm.inputPort;
        connect clockwork.torquePort to drum.rotationPort;

        // State machine
        state machine operation {
            state idle {
                entry action {
                    assign operatingState := "idle";
                }
            }

            state recording {
                entry action {
                    assign operatingState := "recording";
                    assign chartLoaded := true;
                    perform drum.startRotation();
                    perform clockwork.step();
                }
                do action {
                    perform aneroidCapsule.update();
                    perform linkage.transfer();
                    perform recordingArm.update();
                    perform clockwork.step();
                    perform drum.step();
                }
                exit action {
                    perform drum.stopRotation();
                }
            }

            state maintenance {
                entry action {
                    assign operatingState := "maintenance";
                    perform drum.stopRotation();
                    perform drum.chartPaper.replace();
                    perform recordingArm.pen.refillInk();
                }
                exit action {
                    assign maintenanceDone := true;
                }
            }

            transition initial to idle;
            transition idle to recording when chartLoaded;
            transition recording to maintenance when drum.chartPaper.isFull;
            transition maintenance to idle when maintenanceDone;
        }
    }

    // ============================================================
    // Satisfactions
    // ============================================================
    satisfaction satisfyPressureRecording of PressureRecordingRequirement by Barograph;
    satisfaction satisfySevenDayRotation of SevenDayRotationRequirement by ClockworkDrum;
    satisfaction satisfyAmplification of AmplificationRequirement by MechanicalLinkage;
    satisfaction satisfyOperationalStates of OperationalStateRequirement by Barograph;
    satisfaction satisfyAneroidSensitivity of AneroidSensitivityRequirement by AneroidCapsule;

    // ============================================================
    // Verification cases
    // ============================================================
    verification def VerifySevenDayRotation {
        subject drum : ClockworkDrum;
        objective {
            doc /* Confirm the drum completes one revolution in seven days under nominal spring torque. */;
        }
        attribute measuredPeriod : DurationValue;
        attribute tolerance : DurationValue = 0.1;
        action def runTest {
            assign measuredPeriod := drum.rotationPeriod;
            assign pass := abs(measuredPeriod - 7.0) <= tolerance;
        }
    }

    verification def VerifyAmplification {
        subject linkage : MechanicalLinkage;
        objective {
            doc /* Confirm the linkage amplifies input displacement by at least 50 times. */;
        }
        attribute inputDisplacement : LengthValue = 1.0;
        attribute measuredOutput : LengthValue;
        action def runTest {
            perform linkage.transfer();
            assign measuredOutput := linkage.outputPort.displacement;
            assign pass := (measuredOutput / inputDisplacement) >= 50.0;
        }
    }

    // ============================================================
    // Use case
    // ============================================================
    use case def RecordAtmosphericPressure {
        subject operator : Barograph;
        objective {
            doc /* An operator uses the barograph to continuously record atmospheric pressure over a 7-day period. */;
        }
        part user : Barograph;
        part environment : AmbientAir {
            attribute pressure : PressureValue = 1013.25;
        }
    }
}
