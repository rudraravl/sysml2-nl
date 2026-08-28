package LaundryFoldingMachineModel {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        enum def GarmentCategory {
            tshirt;
            pants;
            towel;
        }

        item def Garment {
            attribute category : GarmentCategory;
            attribute width : LengthValue;
            attribute length : LengthValue;
        }

        item def FoldedGarment :> Garment {
            attribute foldCount : Integer;
        }

        attribute def ScanResult {
            attribute category : GarmentCategory;
            attribute width : LengthValue;
            attribute length : LengthValue;
        }

        attribute def FoldCommand {
            attribute commandType : String;
            attribute targetAngle : Real;
        }

        attribute def FoldPlan {
            attribute commands : FoldCommand [0..*];
        }

        attribute def TemperatureSetting {
            attribute targetTemperature : TemperatureValue;
        }

        attribute def GarmentPlacedSignal;
        attribute def DoneSignal;
        attribute def StackFullSignal;
        attribute def EnableSignal;

        action def TransportGarment {
            in item inGarment : Garment;
            out item outGarment : Garment;
        }

        action def ScanGarment {
            in item inGarment : Garment;
            out item scanResult : ScanResult;
            out item scannedGarment : Garment;
        }

        action def AnalyzeGarment {
            in item scanResult : ScanResult;
            out item plan : FoldPlan;
        }

        action def ExecuteFolds {
            in item command : FoldCommand;
            in item garment : Garment;
            out item foldedGarment : FoldedGarment;
        }

        action def StackGarment {
            in item foldedGarment : FoldedGarment;
        }

        action def AdjustSurfaceTemperature {
            in item setting : TemperatureSetting;
        }

        state def LaundryMachineStates;

        part def InputConveyor {
            out item garment : Garment;
            in item enable : EnableSignal;
            perform action transport : TransportGarment;
        }

        part def VisionSystem {
            in item garment : Garment;
            out item scanResult : ScanResult;
            out item scannedGarment : Garment;
            perform action scan : ScanGarment;
        }

        part def ProcessController {
            in item scanResult : ScanResult;
            out item command1 : FoldCommand;
            out item command2 : FoldCommand;
            out item temperatureSetting : TemperatureSetting;
            in item arm1Done : DoneSignal;
            in item arm2Done : DoneSignal;
            in item stackFull : StackFullSignal;
            out item conveyorEnable : EnableSignal;
            perform action analyze : AnalyzeGarment;
        }

        part def FoldingArm {
            in item command : FoldCommand;
            out item done : DoneSignal;
            perform action fold : ExecuteFolds;
        }

        part def FoldingSurface {
            in item garment : Garment;
            in item temperatureSetting : TemperatureSetting;
            out item foldedGarment : FoldedGarment;
            attribute temperature : TemperatureValue;
            part arm1 : FoldingArm;
            part arm2 : FoldingArm;
            perform action adjustTemp : AdjustSurfaceTemperature;
        }

        part def OutputStacker {
            in item foldedGarment : FoldedGarment;
            out item stackFull : StackFullSignal;
            attribute capacity : Integer = 50;
            attribute count : Integer = 0;
            perform action stack : StackGarment;
        }

        part def LaundryFoldingMachine {
            attribute foldingRate : Real;
            attribute foldingPrecision : Boolean;

            part inputConveyor : InputConveyor;
            part visionSystem : VisionSystem;
            part controller : ProcessController;
            part foldingSurface : FoldingSurface;
            part outputStacker : OutputStacker;

            flow from inputConveyor.garment to visionSystem.garment;
            flow from visionSystem.scanResult to controller.scanResult;
            flow from visionSystem.scannedGarment to foldingSurface.garment;
            flow from controller.command1 to foldingSurface.arm1.command;
            flow from controller.command2 to foldingSurface.arm2.command;
            flow from controller.temperatureSetting to foldingSurface.temperatureSetting;
            flow from foldingSurface.arm1.done to controller.arm1Done;
            flow from foldingSurface.arm2.done to controller.arm2Done;
            flow from foldingSurface.foldedGarment to outputStacker.foldedGarment;
            flow from outputStacker.stackFull to controller.stackFull;
            flow from controller.conveyorEnable to inputConveyor.enable;
        }

        requirement def ThroughputRequirement {
            doc /* The system shall fold at least 15 garments per hour. */
        }

        requirement def QualityRequirement {
            doc /* The system shall fold garments with high precision and consistent quality. */
        }

        requirement def SingleItemRequirement {
            doc /* The system shall process exactly one garment at a time. */
        }
    }

    package Usages {
        private import Definitions::*;

        part foldingMachine : LaundryFoldingMachine {
            action 'transport garment' : TransportGarment;
            action 'scan garment' : ScanGarment;
            action 'analyze garment' : AnalyzeGarment;
            action 'fold garment' : ExecuteFolds;
            action 'stack garment' : StackGarment;
            action 'adjust surface temperature' : AdjustSurfaceTemperature;

            state machineStates : LaundryMachineStates {
                entry; then idle;

                state idle;
                transition
                    first idle
                    accept GarmentPlacedSignal
                    then loading;

                state loading {
                    do 'transport garment';
                }
                transition first loading then scanning;

                state scanning {
                    do 'scan garment';
                }
                transition first scanning then planning;

                state planning {
                    do 'analyze garment';
                }
                transition first planning then folding;

                state folding {
                    entry 'adjust surface temperature';
                    do 'fold garment';
                }
                transition first folding then stacking;

                state stacking {
                    do 'stack garment';
                }
                transition
                    first stacking
                    accept StackFullSignal
                    then full;
                transition first stacking then idle;

                state full;
                transition
                    first full
                    accept DoneSignal
                    then idle;
            }
        }

        requirement minimumThroughput : ThroughputRequirement;
        requirement foldingQuality : QualityRequirement;
        requirement singleItemProcessing : SingleItemRequirement;
    }
}
