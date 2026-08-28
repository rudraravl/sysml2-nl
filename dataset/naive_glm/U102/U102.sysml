package PenisExtenderSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type ForceValue :> Real { unit "N"; }
    value type LengthValue :> Real { unit "mm"; }
    value type DurationValue :> Real { unit "h"; }
    value type PressureValue :> Real { unit "kPa"; }
    value type MassValue :> Real { unit "g"; }

    // ---- Item definitions ----
    item def TractionForce {
        attr magnitude : ForceValue;
        attr direction : String = "axial";
    }

    item def AdjustmentCommand {
        attr deltaLength : LengthValue;
    }

    item def SensorReading {
        attr measuredForce : ForceValue;
        attr timestamp : DurationValue;
    }

    // ---- Port definitions ----
    port def RodEndPort {
        out transmittedForce : TractionForce;
    }

    port def AdjusterPort {
        in command : AdjustmentCommand;
        out reportedLength : LengthValue;
    }

    port def SensorPort {
        out reading : SensorReading;
    }

    // ---- Requirement definitions ----
    requirement def SafeTractionRequirement {
        doc /* The applied traction force shall remain within safe physiologically acceptable limits to prevent injury. */
        subject appliedForce : TractionForce;
        constraint { appliedForce.magnitude >= 5.0 and appliedForce.magnitude <= 15.0 }
    }

    requirement def ComfortRequirement {
        doc /* The device shall provide comfort padding at key contact points for multi-hour wear sessions. */
        attr contactPressure : PressureValue;
        constraint { contactPressure <= 20.0 }
    }

    requirement def AdjustabilityRequirement {
        doc /* Extension rods shall be adjustable in length to apply controlled traction. */
        attr rodLength : LengthValue;
        constraint { rodLength >= 80.0 and rodLength <= 250.0 }
    }

    requirement def BiocompatibilityRequirement {
        doc /* All tissue-contacting components shall be made of certified biocompatible medical-grade materials. */
    }

    requirement def LifecycleRequirement {
        doc /* The device shall operate through idle, fitting, tensioning, active wear, and back to idle states. */
    }

    // ---- Component part definitions ----
    part def BaseRing {
        attr material : String = "Certified biocompatible medical-grade silicone";
        attr innerDiameter : LengthValue = 40.0;
        attr outerDiameter : LengthValue = 55.0;
        attr mass : MassValue = 35.0;
        port rodInterface : RodEndPort;
    }

    part def ExtensionRod {
        attr material : String = "Anodized aluminum alloy";
        attr minLength : LengthValue = 80.0;
        attr maxLength : LengthValue = 250.0;
        attr currentLength : LengthValue = 120.0;
        attr threadPitch : LengthValue = 1.0;
        port baseEnd : RodEndPort;
        port cradleEnd : RodEndPort;
        port adjusterInterface : AdjusterPort;

        action def ExtendBy {
            in delta : LengthValue;
            then UpdateLength;
            action UpdateLength {
                if (currentLength + delta <= maxLength and currentLength + delta >= minLength) {
                    currentLength := currentLength + delta;
                }
            }
        }

        action def TransmitForce {
            in inputForce : TractionForce;
            out outputForce : TractionForce;
            action {
                outputForce := inputForce;
            }
        }
    }

    part def GlansCradle {
        attr material : String = "Padded biocompatible silicone";
        attr cradleDiameter : LengthValue = 30.0;
        attr paddingThickness : LengthValue = 4.0;
        port rodInterface : RodEndPort;
    }

    part def TensionAdjuster {
        attr stepSize : LengthValue = 2.5;
        attr detents : Integer = 20;
        port rodInterface : AdjusterPort;

        action def IncreaseTension {
            out command : AdjustmentCommand;
            action {
                command.deltaLength := stepSize;
            }
        }

        action def DecreaseTension {
            out command : AdjustmentCommand;
            action {
                command.deltaLength := -stepSize;
            }
        }

        action def SetTension {
            in targetForce : ForceValue;
            in currentForce : ForceValue;
            out command : AdjustmentCommand;
            action {
                if (currentForce < targetForce) {
                    command.deltaLength := stepSize;
                } else if (currentForce > targetForce) {
                    command.deltaLength := -stepSize;
                } else {
                    command.deltaLength := 0.0;
                }
            }
        }
    }

    part def ForceSensor {
        attr sensorType : String = "Strain gauge load cell";
        attr samplingRate : Real = 10.0;
        attr minSafeForce : ForceValue = 5.0;
        attr maxSafeForce : ForceValue = 15.0;
        attr measuredForce : ForceValue = 0.0;
        attr overForceAlarm : Boolean = false;
        port sensorOut : SensorPort;

        action def MonitorForce {
            in appliedForce : TractionForce;
            out reading : SensorReading;
            action {
                measuredForce := appliedForce.magnitude;
                overForceAlarm := (measuredForce > maxSafeForce);
                reading.measuredForce := measuredForce;
            }
        }

        action def ContinuousMonitor {
            loop {
                MonitorForce;
            }
        }
    }

    part def ComfortPadding {
        attr material : String = "Soft biocompatible medical foam";
        attr thickness : LengthValue = 5.0;
        attr location : String;
        attr contactPressure : PressureValue = 12.0;
    }

    // ---- Main assembly ----
    part def PenisExtender {
        attr deviceName : String = "PenisExtenderSystem";
        attr targetForce : ForceValue = 10.0;
        attr maxSessionDuration : DurationValue = 8.0;
        attr currentSessionDuration : DurationValue = 0.0;

        port systemSensorOut : SensorPort;

        part baseRing : BaseRing {
            attr location : String = "base anchor";
        }

        part extensionRods : ExtensionRod[2] {
            attr location : String = "parallel extension";
        }

        part glansCradle : GlansCradle {
            attr location : String = "distal cradle";
        }

        part tensionAdjusters : TensionAdjuster[2];

        part forceSensor : ForceSensor;

        part comfortPads : ComfortPadding[3] {
            part basePad : ComfortPadding { attr location : String = "base ring"; }
            part cradlePad : ComfortPadding { attr location : String = "glans cradle"; }
            part shaftPad : ComfortPadding { attr location : String = "shaft"; }
        }

        connection baseToRod connect baseRing.rodInterface to extensionRods.baseEnd;
        connection rodToCradle connect extensionRods.cradleEnd to glansCradle.rodInterface;
        connection adjusterToRod connect tensionAdjusters.rodInterface to extensionRods.adjusterInterface;
        connection sensorToSystem connect forceSensor.sensorOut to systemSensorOut;

        // Requirement usages and satisfaction
        requirement safeTraction : SafeTractionRequirement;
        requirement comfort : ComfortRequirement;
        requirement adjustability : AdjustabilityRequirement;
        requirement biocompatibility : BiocompatibilityRequirement;
        requirement lifecycle : LifecycleRequirement;

        satisfy safeTraction by forceSensor;
        satisfy comfort by comfortPads;
        satisfy adjustability by extensionRods;
        satisfy biocompatibility by baseRing;
        satisfy biocompatibility by glansCradle;
        satisfy lifecycle by self;

        // ---- State machine ----
        state def ExtenderLifecycle {
            entry action { currentSessionDuration := 0.0; }
            then idle;

            state idle {
                entry action { forceSensor.measuredForce := 0.0; }
            }

            state fitting {
                entry action { /* user dons device */ }
            }

            state tensioning {
                entry action { /* user adjusts tension */ }
                do action {
                    tensionAdjusters.SetTension(targetForce, forceSensor.measuredForce);
                }
            }

            state activeWear {
                entry action { currentSessionDuration := 0.0; }
                do action {
                    forceSensor.ContinuousMonitor;
                }
            }

            transition idle_to_fitting
                first idle
                then fitting
                when userStartsFitting;

            transition fitting_to_tensioning
                first fitting
                then tensioning
                when deviceFitted;

            transition tensioning_to_activeWear
                first tensioning
                then activeWear
                when targetForceReached;

            transition activeWear_to_idle
                first activeWear
                then idle
                when sessionComplete or forceSensor.overForceAlarm;
        }

        exhibit state lifecycle : ExtenderLifecycle;

        // ---- Operational actions ----
        action def ApplyTraction {
            in target : ForceValue;
            out applied : TractionForce;
            action {
                applied.magnitude := target;
                applied.direction := "axial";
            }
        }

        action def EndSession {
            action {
                forceSensor.measuredForce := 0.0;
                currentSessionDuration := 0.0;
            }
        }
    }
}
