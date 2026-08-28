package 'Femtotechnology Transmutation System' {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def ProtonCount :> ScalarValues::Integer;
    attribute def NeutronCount :> ScalarValues::Integer;

    item def NuclearComposition {
        attribute protons : ProtonCount;
        attribute neutrons : NeutronCount;
    }

    item def ScanResult {
        attribute composition : NuclearComposition;
    }

    item def TargetSpec {
        attribute targetProtons : ProtonCount;
        attribute targetNeutrons : NeutronCount;
    }

    item def TransmutationPlan {
        attribute protonsToAdd : ProtonCount;
        attribute protonsToRemove : ProtonCount;
        attribute neutronsToAdd : NeutronCount;
        attribute neutronsToRemove : NeutronCount;
    }

    item def FieldParameters {
        attribute intensity : PowerValue;
        attribute frequency : Real;
    }

    item def ManipulationCommand {
        attribute addProtons : ProtonCount;
        attribute removeProtons : ProtonCount;
        attribute addNeutrons : NeutronCount;
        attribute removeNeutrons : NeutronCount;
    }

    item def VerificationResult {
        attribute success : Boolean;
        attribute finalComposition : NuclearComposition;
    }

    item def StartCommand;
    item def ScanCommand;

    part def ContainmentChamber {
        port sourceMaterialPort {
            in sourceMaterial : MassValue;
        }
        port scanPort {
            out scanTarget : MassValue;
        }
        port fieldPort {
            in field : FieldParameters;
        }
        port manipulationPort {
            in command : ManipulationCommand;
        }
        port productPort {
            out productMaterial : MassValue;
        }
        attribute shieldingIntegrity : Boolean;
    }

    part def NuclearScanner {
        port scanTargetPort {
            in scanTarget : MassValue;
        }
        port scanCommandPort {
            in scanCommand : ScanCommand;
        }
        port scanResultPort {
            out result : ScanResult;
        }

        action def ScanAction {
            in target : MassValue;
            out result : ScanResult;
        }

        action scanBehavior : ScanAction {
            in target = scanTargetPort.scanTarget;
            out result = scanResultPort.result;
        }
    }

    part def ProcessController {
        port startPort {
            in startCommand : StartCommand;
        }
        port targetSpecPort {
            in target : TargetSpec;
        }
        port scanResultPort {
            in result : ScanResult;
        }
        port scanCommandPort {
            out scanCommand : ScanCommand;
        }
        port fieldCommandPort {
            out fieldParams : FieldParameters;
        }
        port manipulationCommandPort {
            out command : ManipulationCommand;
        }
        port verificationPort {
            in verification : VerificationResult;
        }
        port statusPort {
            out status : Boolean;
        }
        port powerControlPort {
            out enable : Boolean;
        }

        attribute currentComposition : NuclearComposition;
        attribute targetSpec : TargetSpec;
        attribute transmutationPlan : TransmutationPlan;

        action def CreatePlanAction {
            in currentComposition : NuclearComposition;
            in targetProtons : ProtonCount;
            in targetNeutrons : NeutronCount;
            out plan : TransmutationPlan;
        }

        action def GenerateFieldParamsAction {
            in plan : TransmutationPlan;
            out fieldParams : FieldParameters;
        }

        action def GenerateCommandAction {
            in plan : TransmutationPlan;
            out command : ManipulationCommand;
        }

        action def VerifyResultAction {
            in verification : VerificationResult;
            in targetProtons : ProtonCount;
            in targetNeutrons : NeutronCount;
            out success : Boolean;
        }

        state controllerStateMachine {
            state idle;
            transition t0 first idle accept StartCommand via startPort then scanning;
            state scanning;
            transition t1 first scanning accept ScanResult via scanResultPort then planning;
            state planning;
            transition t2 first planning then executing;
            state executing;
            transition t3 first executing accept VerificationResult via verificationPort then verifying;
            state verifying;
            transition t4 first verifying then complete;
            state complete;
            transition t5 first complete then idle;
        }
    }

    part def FemtoFieldGenerator {
        port powerPort {
            in power : PowerValue;
        }
        port fieldCommandPort {
            in fieldParams : FieldParameters;
        }
        port fieldOutputPort {
            out field : FieldParameters;
        }

        action def GenerateFieldAction {
            in power : PowerValue;
            in params : FieldParameters;
            out field : FieldParameters;
        }

        action generateFieldBehavior : GenerateFieldAction {
            in power = powerPort.power;
            in params = fieldCommandPort.fieldParams;
            out field = fieldOutputPort.field;
        }
    }

    part def NucleonManipulator {
        port fieldInputPort {
            in field : FieldParameters;
        }
        port commandPort {
            in command : ManipulationCommand;
        }
        port chamberFieldPort {
            out focusedField : FieldParameters;
        }
        port chamberCommandPort {
            out command : ManipulationCommand;
        }
        port resultPort {
            out result : VerificationResult;
        }

        action def ManipulateAction {
            in field : FieldParameters;
            in command : ManipulationCommand;
            out result : VerificationResult;
        }

        action manipulateBehavior : ManipulateAction {
            in field = fieldInputPort.field;
            in command = commandPort.command;
            out result = resultPort.result;
        }
    }

    part def PowerSource {
        port powerOutputPort {
            out power : PowerValue;
        }
        port controlPort {
            in enable : Boolean;
        }
        attribute maxPower : PowerValue = 1000000.0;
    }

    part def ControlInterface {
        port targetSpecPort {
            out target : TargetSpec;
        }
        port startPort {
            out startCommand : StartCommand;
        }
        port statusPort {
            in status : Boolean;
        }
    }

    requirement def ContainmentSafetyRequirement {
        doc /* The containment chamber must prevent any radiation leakage during operation to ensure safety. */
    }

    requirement def ScanningAccuracyRequirement {
        doc /* The nuclear scanner must determine proton and neutron counts with exact precision. */
    }

    requirement def TransmutationPrecisionRequirement {
        doc /* The system must add or remove exactly the specified number of protons and neutrons to achieve the target element. */
    }

    requirement def PowerSupplyRequirement {
        doc /* The power source must supply a minimum of 1 MW to sustain the femto field generator during execution. */
        attribute minPower : PowerValue = 1000000.0;
    }

    requirement def VerificationProtocolRequirement {
        doc /* The system must verify the final material composition matches the target specification before completing the process. */
        attribute verificationRequired : Boolean = true;
    }

    part def FemtotechnologySystem {
        part containmentChamber : ContainmentChamber;
        part nuclearScanner : NuclearScanner;
        part processController : ProcessController;
        part femtoFieldGenerator : FemtoFieldGenerator;
        part nucleonManipulator : NucleonManipulator;
        part powerSource : PowerSource;
        part controlInterface : ControlInterface;

        flow scanTargetFlow of MassValue
            from containmentChamber.scanPort.scanTarget to nuclearScanner.scanTargetPort.scanTarget;

        flow scanCommandFlow of ScanCommand
            from processController.scanCommandPort.scanCommand to nuclearScanner.scanCommandPort.scanCommand;

        flow scanResultFlow of ScanResult
            from nuclearScanner.scanResultPort.result to processController.scanResultPort.result;

        flow targetSpecFlow of TargetSpec
            from controlInterface.targetSpecPort.target to processController.targetSpecPort.target;

        flow startCommandFlow of StartCommand
            from controlInterface.startPort.startCommand to processController.startPort.startCommand;

        flow fieldCommandFlow of FieldParameters
            from processController.fieldCommandPort.fieldParams to femtoFieldGenerator.fieldCommandPort.fieldParams;

        flow manipulationCommandFlow of ManipulationCommand
            from processController.manipulationCommandPort.command to nucleonManipulator.commandPort.command;

        flow powerFlow of PowerValue
            from powerSource.powerOutputPort.power to femtoFieldGenerator.powerPort.power;

        flow powerControlFlow of Boolean
            from processController.powerControlPort.enable to powerSource.controlPort.enable;

        flow fieldOutputFlow of FieldParameters
            from femtoFieldGenerator.fieldOutputPort.field to nucleonManipulator.fieldInputPort.field;

        flow focusedFieldFlow of FieldParameters
            from nucleonManipulator.chamberFieldPort.focusedField to containmentChamber.fieldPort.field;

        flow chamberCommandFlow of ManipulationCommand
            from nucleonManipulator.chamberCommandPort.command to containmentChamber.manipulationPort.command;

        flow verificationFlow of VerificationResult
            from nucleonManipulator.resultPort.result to processController.verificationPort.verification;

        flow statusFlow of Boolean
            from processController.statusPort.status to controlInterface.statusPort.status;

        action transmutationProcess {
            action receiveTarget {
                in target : TargetSpec;
            }
            then action initiateScan {
                out scanCommand : ScanCommand;
            }
            then action performScan {
                in target : MassValue;
                out composition : NuclearComposition;
            }
            then action createTransmutationPlan {
                in composition : NuclearComposition;
                in targetProtons : ProtonCount;
                in targetNeutrons : NeutronCount;
                out plan : TransmutationPlan;
            }
            then action generateFields {
                in plan : TransmutationPlan;
                out fieldParams : FieldParameters;
                out command : ManipulationCommand;
            }
            then action executeManipulation {
                in fieldParams : FieldParameters;
                in command : ManipulationCommand;
                out result : VerificationResult;
            }
            then action verifyTransmutation {
                in result : VerificationResult;
                in targetProtons : ProtonCount;
                in targetNeutrons : NeutronCount;
                out verified : Boolean;
            }
        }

        satisfy ContainmentSafetyRequirement by containmentChamber;
        satisfy ScanningAccuracyRequirement by nuclearScanner;
        satisfy TransmutationPrecisionRequirement by nucleonManipulator;
        satisfy PowerSupplyRequirement by powerSource;
        satisfy VerificationProtocolRequirement by processController;
    }
}
