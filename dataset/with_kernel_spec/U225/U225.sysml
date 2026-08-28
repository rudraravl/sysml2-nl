package FiberscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Target;
        item def IlluminationLight {
            attribute power : Real = 150 [W];
            attribute colorTemp : Real = 5500 [K];
        }
        item def ReflectedImage {
            attribute fieldOfView : Real = 75 [deg];
        }
        item def MagnifiedImage {
            attribute magnification : Real = 12;
        }
        item def BendCommand {
            attribute bendAngle : Real;
            attribute bendDirection : String;
        }

        attribute def InsertSignal;
        attribute def PositionSignal;
        attribute def ImageSignal;
        attribute def WithdrawSignal;
        attribute def CompleteSignal;

        part def IlluminationSource;
        part def InsertionTube {
            attribute length : Real = 1.2 [m];
            attribute diameter : Real = 5.5 [mm];
            attribute illuminationFiberCount : Integer = 30000;
            attribute imageFiberCount : Integer = 18000;
        }
        part def ObjectiveLensAssembly {
            attribute fieldOfView : Real = 75 [deg];
        }
        part def ArticulationController {
            attribute maxBendAngle : Real = 120 [deg];
            attribute controlType : String = "four-way lever";
        }
        part def EyepieceViewer {
            attribute magnification : Real = 12;
        }

        action def Illuminate {
            out illumLight : IlluminationLight;
        }
        action def InsertTube {
            in illumLight : IlluminationLight;
            out tipLight : IlluminationLight;
        }
        action def PositionTip {
            in bendCmd : BendCommand;
        }
        action def CaptureImage {
            in tipLight : IlluminationLight;
            out capturedImage : ReflectedImage;
        }
        action def RelayImage {
            in capturedImage : ReflectedImage;
            out relayedImage : ReflectedImage;
        }
        action def ViewImage {
            in relayedImage : ReflectedImage;
            out finalImage : MagnifiedImage;
        }
        action def Inspect {
            in light : IlluminationLight;
            in bendCmd : BendCommand;
            out finalImage : MagnifiedImage;
        }

        state def FiberscopeStates;

        requirement def IlluminationRequirement {
            doc /* The illumination source must produce daylight-like light at 150W and 5500K. */
            attribute minPower : Real = 150 [W];
            attribute targetColorTemp : Real = 5500 [K];
        }
        requirement def InsertionTubeRequirement {
            doc /* The insertion tube must be 1.2 m long and 5.5 mm in diameter. */
            attribute requiredLength : Real = 1.2 [m];
            attribute requiredDiameter : Real = 5.5 [mm];
        }
        requirement def ArticulationRequirement {
            doc /* The articulation controller must bend the tip up to 120 degrees. */
            attribute maxBendAngle : Real = 120 [deg];
        }
        requirement def ImageBundleRequirement {
            doc /* The image bundle must contain 18000 coherent optical fibers. */
            attribute fiberCount : Integer = 18000;
        }
        requirement def MagnificationRequirement {
            doc /* The eyepiece must provide 12x magnification. */
            attribute magnification : Real = 12;
        }
    }

    package Usages {
        private import Definitions::*;

        part fiberscope {
            ref item target : Target;

            part illuminationSource : IlluminationSource {
                out item light : IlluminationLight;
            }
            part insertionTube : InsertionTube {
                in item illuminationLight : IlluminationLight;
                out item tipLight : IlluminationLight;
                in item capturedImage : ReflectedImage;
                out item relayedImage : ReflectedImage;
            }
            part objectiveLens : ObjectiveLensAssembly {
                in item tipLight : IlluminationLight;
                in item bendCommand : BendCommand;
                ref item target : Target = fiberscope::target;
                out item capturedImage : ReflectedImage;
            }
            part articulationController : ArticulationController {
                out item bendCommand : BendCommand;
            }
            part eyepieceViewer : EyepieceViewer {
                in item relayedImage : ReflectedImage;
                out item finalImage : MagnifiedImage;
            }

            flow illuminationSource.light to insertionTube.illuminationLight;
            flow insertionTube.tipLight to objectiveLens.tipLight;
            flow objectiveLens.capturedImage to insertionTube.capturedImage;
            flow insertionTube.relayedImage to eyepieceViewer.relayedImage;
            flow articulationController.bendCommand to objectiveLens.bendCommand;

            exhibit state 'fiberscope states' : FiberscopeStates {
                entry;
                then idle;

                state idle;
                accept InsertSignal
                    then inserting;

                state inserting;
                accept PositionSignal
                    then positioning;

                state positioning;
                accept ImageSignal
                    then imaging;

                state imaging;
                accept WithdrawSignal
                    then withdrawing;

                state withdrawing;
                accept CompleteSignal
                    then idle;
            }
        }

        action inspect : Inspect {
            in item light;
            in item bendCmd;
            out item finalImage;

            action illuminate : Illuminate {
                in item light = inspect::light;
                out item illumLight;
            }
            flow from illuminate.illumLight to insert.illumLight;
            action insert : InsertTube {
                in item illumLight;
                out item tipLight;
            }
            flow from insert.tipLight to capture.tipLight;
            action position : PositionTip {
                in item bendCmd = inspect::bendCmd;
            }
            action capture : CaptureImage {
                in item tipLight;
                out item capturedImage;
            }
            flow from capture.capturedImage to relayImg.capturedImage;
            action relayImg : RelayImage {
                in item capturedImage;
                out item relayedImage;
            }
            flow from relayImg.relayedImage to viewImg.relayedImage;
            action viewImg : ViewImage {
                in item relayedImage;
                out item finalImage = inspect::finalImage;
            }
        }
    }
}
