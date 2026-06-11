package InjectorPenSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Milliliter :> Real;
    attribute def MilliliterPerSecond :> Real;
    attribute def Milligram :> Real;
    attribute def InternationalUnit :> Real;
    attribute def Newton :> Real;
    attribute def Percent :> Real;
    attribute def Second :> Real;
    attribute def Millimeter :> Real;
    attribute def DegreeCelsius :> Real;
    attribute def Boolean :> ScalarValues::Boolean;

    item def Medication {
        attribute concentration : Milligram;
        attribute remainingVolume : Milliliter;
        attribute doseVolume : Milliliter;
        attribute storageTemperature : DegreeCelsius;
    }

    item def Force {
        attribute magnitude : Newton;
    }

    item def InjectionCommand {
        attribute requestedDose : Milliliter;
        attribute primingRequested : Boolean;
    }

    item def DoseIndication {
        attribute selectedDose : Milliliter;
        attribute deliveredDose : Milliliter;
        attribute doseComplete : Boolean;
        attribute faultActive : Boolean;
    }

    item def AudibleSignal {
        attribute clickCount : Integer;
        attribute completionTone : Boolean;
    }

    port def MechanicalForcePort {
        in item appliedForce : Force;
    }

    port def MedicationFlowPort {
        out item medicationFlow : Medication;
    }

    port def UserCommandPort {
        in item command : InjectionCommand;
    }

    port def UserFeedbackPort {
        out item indication : DoseIndication;
        out item signal : AudibleSignal;
    }

    part def CartridgeAssembly {
        attribute nominalFillVolume : Milliliter = 3.0;
        attribute minimumUsableVolume : Milliliter = 0.05;
        attribute currentVolume : Milliliter;
        attribute medicationConcentration : Milligram;
        attribute sealIntegrityOk : Boolean;

        port outlet : MedicationFlowPort;

        action dispenseMedication {
            in doseVolume : Milliliter;
            out deliveredMedication : Medication;

            first start;
            then verifyVolume;
            then moveStopper;
            then releaseFlow;
            then done;

            assert constraint {
                doseVolume <= currentVolume - minimumUsableVolume
            }
        }
    }

    part def NeedleAssembly {
        attribute needleLength : Millimeter = 4.0;
        attribute innerDiameter : Millimeter = 0.23;
        attribute attached : Boolean;
        attribute occluded : Boolean;
        attribute sterileBarrierIntact : Boolean;

        port inlet : MedicationFlowPort;
        port outlet : MedicationFlowPort;

        action conductMedication {
            in incomingMedication : Medication;
            out injectedMedication : Medication;

            first receiveMedication;
            then checkNeedlePath;
            then deliverThroughNeedle;
            then complete;

            assert constraint {
                attached == true and occluded == false
            }
        }
    }

    part def DoseSelector {
        attribute minimumDose : Milliliter = 0.01;
        attribute maximumDose : Milliliter = 0.60;
        attribute doseIncrement : Milliliter = 0.01;
        attribute selectedDose : Milliliter;
        attribute locked : Boolean;

        port commandPort : UserCommandPort;
        port feedbackPort : UserFeedbackPort;

        action selectDose {
            in requestedDose : Milliliter;
            out acceptedDose : Milliliter;

            first receiveSelection;
            then limitToRange;
            then snapToIncrement;
            then displayDose;

            assert constraint {
                acceptedDose >= minimumDose and acceptedDose <= maximumDose
            }
        }
    }

    part def DriveMechanism {
        attribute plungerTravelPerIncrement : Millimeter = 0.08;
        attribute driveEfficiency : Percent = 92.0;
        attribute availableSpringForce : Newton = 18.0;
        attribute requiredInjectionForce : Newton;
        attribute plungerPosition : Millimeter;

        port forceInput : MechanicalForcePort;

        action advancePlunger {
            in selectedDose : Milliliter;
            out driveForce : Force;

            first armed;
            then receiveActivationForce;
            then translateForceToTravel;
            then advanceCartridgeStopper;
            then holdEndPosition;
        }
    }

    part def InjectionButton {
        attribute depressed : Boolean;
        attribute activationForceThreshold : Newton = 8.0;
        attribute fullStrokeTravel : Millimeter = 6.0;

        port forcePort : MechanicalForcePort;

        action acceptPress {
            in userForce : Force;
            out acceptedForce : Force;

            first idle;
            then sensePress;
            then validateForce;
            then transferForce;

            assert constraint {
                userForce.magnitude >= activationForceThreshold
            }
        }
    }

    part def DoseIndicator {
        attribute displayedDose : Milliliter;
        attribute deliveredDose : Milliliter;
        attribute completionVisible : Boolean;
        attribute faultVisible : Boolean;

        port feedbackPort : UserFeedbackPort;

        action updateDisplay {
            in selectedDose : Milliliter;
            in deliveredDoseInput : Milliliter;
            in fault : Boolean;
            out displayState : DoseIndication;

            first readInputs;
            then computeCompletion;
            then showDose;
            then showFaultIfNeeded;
        }
    }

    part def FeedbackClicker {
        attribute clicksPerIncrement : Integer = 1;
        attribute endOfDoseClickEnabled : Boolean = true;

        port feedbackPort : UserFeedbackPort;

        action emitFeedback {
            in selectedDose : Milliliter;
            in doseIncrement : Milliliter;
            in complete : Boolean;
            out signal : AudibleSignal;

            first countDoseClicks;
            then emitSelectionClicks;
            then emitCompletionClick;
        }
    }

    part def Cap {
        attribute installed : Boolean;
        attribute protectsNeedle : Boolean = true;
        attribute preventsAccidentalButtonPress : Boolean = true;
    }

    part def InjectorPen {
        attribute reusable : Boolean = false;
        attribute readyForUse : Boolean;
        attribute selectedDose : Milliliter;
        attribute deliveredDose : Milliliter;
        attribute doseAccuracyTolerance : Percent = 5.0;
        attribute maxInjectionDuration : Second = 15.0;
        attribute ambientOperatingTemperatureMin : DegreeCelsius = 2.0;
        attribute ambientOperatingTemperatureMax : DegreeCelsius = 30.0;

        port userCommand : UserCommandPort;
        port userFeedback : UserFeedbackPort;
        port medicationOutlet : MedicationFlowPort;
        port userForceInput : MechanicalForcePort;

        part cartridge : CartridgeAssembly;
        part needle : NeedleAssembly;
        part selector : DoseSelector;
        part drive : DriveMechanism;
        part button : InjectionButton;
        part indicator : DoseIndicator;
        part clicker : FeedbackClicker;
        part cap : Cap;

        connect userCommand to selector.commandPort;
        connect selector.feedbackPort to userFeedback;
        connect indicator.feedbackPort to userFeedback;
        connect clicker.feedbackPort to userFeedback;
        connect userForceInput to button.forcePort;
        connect button.forcePort to drive.forceInput;
        connect cartridge.outlet to needle.inlet;
        connect needle.outlet to medicationOutlet;

        action performPrimaryFunction {
            in command : InjectionCommand;
            in userPressForce : Force;
            out doseReport : DoseIndication;

            first receiveUserDoseSelection;
            then setDose via selector.selectDose;
            then confirmReadyState;
            then acceptInjectionPress via button.acceptPress;
            then driveDose via drive.advancePlunger;
            then dispenseDose via cartridge.dispenseMedication;
            then conductDose via needle.conductMedication;
            then updateDoseFeedback via indicator.updateDisplay;
            then emitCompletionFeedback via clicker.emitFeedback;
            then completeInjection;

            assert constraint {
                deliveredDose >= selectedDose * (1.0 - doseAccuracyTolerance / 100.0) and
                deliveredDose <= selectedDose * (1.0 + doseAccuracyTolerance / 100.0)
            }
        }

        state def InjectorPenOperationalStates {
            state Capped;
            state Uncapped;
            state NeedleAttached;
            state DoseSelection;
            state Armed;
            state Injecting;
            state DoseComplete;
            state Fault;

            entry action initialize {
                readyForUse = false;
                deliveredDose = 0.0;
            }

            transition first Capped;
            transition Capped_to_Uncapped
                first Capped
                accept removeCap
                then Uncapped;

            transition Uncapped_to_NeedleAttached
                first Uncapped
                accept attachNeedle
                then NeedleAttached;

            transition NeedleAttached_to_DoseSelection
                first NeedleAttached
                accept beginDoseSelection
                then DoseSelection;

            transition DoseSelection_to_Armed
                first DoseSelection
                accept doseSelected
                if selectedDose > 0.0
                then Armed;

            transition Armed_to_Injecting
                first Armed
                accept pressInjectionButton
                if needle.attached == true and needle.occluded == false and cartridge.currentVolume >= selectedDose
                then Injecting;

            transition Injecting_to_DoseComplete
                first Injecting
                accept doseDelivered
                if deliveredDose >= selectedDose * 0.95
                then DoseComplete;

            transition Any_to_Fault
                first Capped
                accept detectedFault
                then Fault;

            transition Any_to_Fault_2
                first Uncapped
                accept detectedFault
                then Fault;

            transition Any_to_Fault_3
                first NeedleAttached
                accept detectedFault
                then Fault;

            transition Any_to_Fault_4
                first DoseSelection
                accept detectedFault
                then Fault;

            transition Any_to_Fault_5
                first Armed
                accept detectedFault
                then Fault;

            transition Any_to_Fault_6
                first Injecting
                accept detectedFault
                then Fault;

            transition DoseComplete_to_Capped
                first DoseComplete
                accept installCap
                then Capped;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject pen : InjectorPen;

        doc
        /*
         * The injector pen shall enable a user to select a medication dose and deliver that dose
         * through an attached needle into the injection site by converting a manual button press
         * into controlled plunger motion against a medication cartridge.
         */

        require constraint {
            pen.selectedDose > 0.0 and
            pen.deliveredDose >= pen.selectedDose * 0.95 and
            pen.deliveredDose <= pen.selectedDose * 1.05
        }
    }

    requirement def DoseSelectionRequirement {
        subject pen : InjectorPen;

        require constraint {
            pen.selector.selectedDose >= pen.selector.minimumDose and
            pen.selector.selectedDose <= pen.selector.maximumDose
        }
    }

    requirement def MedicationContainmentRequirement {
        subject pen : InjectorPen;

        require constraint {
            pen.cartridge.sealIntegrityOk == true and
            pen.cartridge.currentVolume >= pen.cartridge.minimumUsableVolume
        }
    }

    requirement def NeedleSafetyRequirement {
        subject pen : InjectorPen;

        require constraint {
            pen.needle.attached == true implies pen.needle.sterileBarrierIntact == false
        }
    }

    requirement def InjectionReadinessRequirement {
        subject pen : InjectorPen;

        require constraint {
            pen.cap.installed == false and
            pen.needle.attached == true and
            pen.needle.occluded == false and
            pen.cartridge.currentVolume >= pen.selectedDose
        }
    }

    requirement def UserFeedbackRequirement {
        subject pen : InjectorPen;

        require constraint {
            pen.indicator.displayedDose == pen.selectedDose and
            pen.indicator.deliveredDose == pen.deliveredDose
        }
    }

    requirement def InjectionDurationRequirement {
        subject pen : InjectorPen;

        require constraint {
            pen.maxInjectionDuration <= 15.0
        }
    }

    part injectorPenSystem : InjectorPen {
        attribute readyForUse = true;
        attribute selectedDose = 0.20;
        attribute deliveredDose = 0.20;

        part cartridge {
            attribute currentVolume = 2.80;
            attribute medicationConcentration = 100.0;
            attribute sealIntegrityOk = true;
        }

        part needle {
            attribute attached = true;
            attribute occluded = false;
            attribute sterileBarrierIntact = false;
        }

        part selector {
            attribute selectedDose = 0.20;
            attribute locked = false;
        }

        part drive {
            attribute requiredInjectionForce = 10.0;
            attribute plungerPosition = 0.0;
        }

        part button {
            attribute depressed = false;
        }

        part indicator {
            attribute displayedDose = 0.20;
            attribute deliveredDose = 0.20;
            attribute completionVisible = true;
            attribute faultVisible = false;
        }

        part cap {
            attribute installed = false;
        }
    }

    satisfy PrimaryFunctionRequirement by injectorPenSystem;
    satisfy DoseSelectionRequirement by injectorPenSystem;
    satisfy MedicationContainmentRequirement by injectorPenSystem;
    satisfy NeedleSafetyRequirement by injectorPenSystem;
    satisfy InjectionReadinessRequirement by injectorPenSystem;
    satisfy UserFeedbackRequirement by injectorPenSystem;
    satisfy InjectionDurationRequirement by injectorPenSystem;
}