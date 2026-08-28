package ATNAA {
    import ScalarValues::*;
    import SI::*;

    // ============================================================
    // Value Types
    // ============================================================
    value type ForceValue > Real { unit "N"; }
    value type PressureValue > Real { unit "Pa"; }
    value type VolumeValue > Real { unit "mL"; }
    value type MassValue > Real { unit "mg"; }
    value type LengthValue > Real { unit "mm"; }
    value type DurationValue > Real { unit "s"; }

    // ============================================================
    // Item Types
    // ============================================================
    item def Atropine {
        attribute concentration : MassValue = 2.0 [mg/mL];
        attribute doseVolume : VolumeValue = 1.5 [mL];
        attribute doseMass : MassValue = 3.0 [mg];
    }

    item def Pralidoxime {
        attribute concentration : MassValue = 600.0 [mg/mL];
        attribute doseVolume : VolumeValue = 2.0 [mL];
        attribute doseMass : MassValue = 1200.0 [mg];
    }

    item def AntidoteMixture {
        part atropine : Atropine;
        part pralidoxime : Pralidoxime;
        attribute totalVolume : VolumeValue = 3.5 [mL];
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def SafetyStatePort {
        out attribute engaged : Boolean;
    }

    port def TriggerSignalPort {
        in attribute triggered : Boolean;
    }

    port def ForceFlowPort {
        out attribute force : ForceValue;
    }

    port def PressureFlowPort {
        out attribute pressure : PressureValue;
    }

    port def AntidoteFlowPort {
        out item antidote : AntidoteMixture;
    }

    port def PressureSignalPort {
        out attribute pressure : PressureValue;
        out attribute doseComplete : Boolean;
    }

    port def IndicatorStatePort {
        out attribute status : String;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def SafetyRequirement {
        subject device :> ATNAA;
        objective {
            doc /* The device shall include a safety mechanism that prevents accidental activation. */
        }
    }

    requirement def DualDrugRequirement {
        subject device :> ATNAA;
        attribute atropineDose : MassValue = 3.0 [mg];
        attribute pralidoximeDose : MassValue = 1200.0 [mg];
        objective {
            doc /* The device shall deliver a pre-filled two-drug antidote consisting of Atropine and Pralidoxime. */
        }
    }

    requirement def AutoInjectionRequirement {
        subject device :> ATNAA;
        attribute maxInjectionTime : DurationValue = 5.0 [s];
        attribute minInjectionPressure : PressureValue = 200000.0 [Pa];
        objective {
            doc /* The device shall automatically inject the antidote into muscle tissue upon activation. */
        }
    }

    requirement def PressureMonitoringRequirement {
        subject device :> ATNAA;
        attribute samplingRate : DurationValue = 0.1 [s];
        objective {
            doc /* The device shall monitor injection pressure to confirm full dose delivery. */
        }
    }

    requirement def VisualIndicatorRequirement {
        subject device :> ATNAA;
        objective {
            doc /* The device shall provide a visual indicator confirming successful administration. */
        }
    }

    // ============================================================
    // Part Definitions
    // ============================================================
    part def SafetyMechanism {
        attribute engaged : Boolean = true;
        port safetyState : SafetyStatePort;

        action disengage {
            out attribute newEngaged : Boolean = false;
        }

        action engage {
            out attribute newEngaged : Boolean = true;
        }
    }

    part def SpringMechanism {
        attribute compressed : Boolean = true;
        attribute springForce : ForceValue = 150.0 [N];
        port trigger : TriggerSignalPort;
        port forceOut : ForceFlowPort;

        action release {
            in attribute triggered : Boolean;
            out attribute releasedForce : ForceValue = springForce;
        }
    }

    part def PlungerAssembly {
        attribute position : LengthValue = 0.0 [mm];
        attribute appliedForce : ForceValue = 0.0 [N];
        port forceIn : ForceFlowPort;
        port pressureOut : PressureFlowPort;

        action advance {
            in attribute force : ForceValue;
            out attribute generatedPressure : PressureValue;
        }
    }

    part def DualChamberCartridge {
        part chamberA : Atropine {
            attribute remainingVolume : VolumeValue = 1.5 [mL];
        }
        part chamberB : Pralidoxime {
            attribute remainingVolume : VolumeValue = 2.0 [mL];
        }
        attribute totalVolume : VolumeValue = 3.5 [mL];
        attribute remainingVolume : VolumeValue = 3.5 [mL];
        port pressureIn : PressureFlowPort;
        port antidoteOut : AntidoteFlowPort;

        action expel {
            in attribute pressure : PressureValue;
            out item expelledAntidote : AntidoteMixture;
        }
    }

    part def NeedleAssembly {
        attribute length : LengthValue = 25.0 [mm];
        attribute deployed : Boolean = false;
        port antidoteIn : AntidoteFlowPort;
        port injectionOut : AntidoteFlowPort;

        action deploy {
            out attribute deployed : Boolean = true;
        }

        action inject {
            in item antidote : AntidoteMixture;
            out item deliveredAntidote : AntidoteMixture;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue = 0.0 [Pa];
        attribute doseComplete : Boolean = false;
        attribute thresholdPressure : PressureValue = 200000.0 [Pa];
        port pressureIn : PressureFlowPort;
        port signalOut : PressureSignalPort;

        action measure {
            in attribute pressure : PressureValue;
            out attribute reportedPressure : PressureValue;
            out attribute complete : Boolean;
        }
    }

    part def VisualIndicator {
        attribute status : String = "Ready";
        port signalIn : PressureSignalPort;
        port indicatorOut : IndicatorStatePort;

        action showReady {
            out attribute status : String = "Ready";
        }

        action showAdministering {
            out attribute status : String = "Administering";
        }

        action showSuccess {
            out attribute status : String = "Complete";
        }
    }

    part def Housing {
        attribute length : LengthValue = 150.0 [mm];
        attribute diameter : LengthValue = 25.0 [mm];
        attribute singleUse : Boolean = true;
    }

    // ============================================================
    // State Machine
    // ============================================================
    state def DeviceStateMachine {
        entry; then Ready;

        state Ready {
            entry action showReady;
        }

        state SafetyDisengaged {
            entry action armDevice;
        }

        state Injecting {
            entry action startInjection;
            do action monitorInjection;
        }

        state Complete {
            entry action showSuccess;
        }

        transition from Ready to SafetyDisengaged
            when safety.safetyState.engaged == false;

        transition from SafetyDisengaged to Injecting
            when spring.trigger.triggered == true;

        transition from Injecting to Complete
            when pressureSensor.signalOut.doseComplete == true;
    }

    // ============================================================
    // Main Device
    // ============================================================
    part def ATNAA {
        satisfy SafetyRequirement;
        satisfy DualDrugRequirement;
        satisfy AutoInjectionRequirement;
        satisfy PressureMonitoringRequirement;
        satisfy VisualIndicatorRequirement;

        part housing : Housing;
        part safety : SafetyMechanism;
        part spring : SpringMechanism;
        part plunger : PlungerAssembly;
        part cartridge : DualChamberCartridge;
        part needle : NeedleAssembly;
        part pressureSensor : PressureSensor;
        part indicator : VisualIndicator;

        port externalInjectionPort : AntidoteFlowPort;

        // Connections
        connection safetyToSpring connect safety.safetyState to spring.trigger;
        connection springToPlunger connect spring.forceOut to plunger.forceIn;
        connection plungerToCartridge connect plunger.pressureOut to cartridge.pressureIn;
        connection cartridgeToNeedle connect cartridge.antidoteOut to needle.antidoteIn;
        connection needleToExternal connect needle.injectionOut to externalInjectionPort;
        connection plungerToSensor connect plunger.pressureOut to pressureSensor.pressureIn;
        connection sensorToIndicator connect pressureSensor.signalOut to indicator.signalIn;

        // Behavior
        exhibit state behavior : DeviceStateMachine;

        action disengageSafety {
            in attribute userCommand : Boolean;
            then safety.disengage;
        }

        action activateInjection {
            in attribute bodyContact : Boolean;
            then spring.release;
            then plunger.advance;
            then cartridge.expel;
            then needle.deploy;
            then needle.inject;
        }

        action confirmDose {
            in attribute pressure : PressureValue;
            then pressureSensor.measure;
            then indicator.showSuccess;
        }
    }
}
