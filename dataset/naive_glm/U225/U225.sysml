package FlexibleFiberscopeSystem {
    import ISQ::*;
    import ScalarValues::*;

    value def PowerValue = Real { unit 'W'; }
    value def TemperatureValue = Real { unit 'K'; }
    value def LengthValue = Real { unit 'm'; }
    value def DiameterValue = Real { unit 'mm'; }
    value def AngleValue = Real { unit 'deg'; }
    value def MagnificationValue = Real;
    value def FiberCountValue = Integer;

    item def IlluminationLight {
        attribute power : PowerValue;
        attribute colorTemp : TemperatureValue;
    }

    item def ReflectedImage {
        attribute fieldOfView : AngleValue;
        attribute magnification : MagnificationValue;
    }

    item def ArticulationCommand {
        attribute direction : String;
        attribute bendAngle : AngleValue;
    }

    port def LightOutPort {
        out light : IlluminationLight;
    }

    port def LightInPort {
        in light : IlluminationLight;
    }

    port def ImageOutPort {
        out image : ReflectedImage;
    }

    port def ImageInPort {
        in image : ReflectedImage;
    }

    port def ControlOutPort {
        out command : ArticulationCommand;
    }

    port def ControlInPort {
        in command : ArticulationCommand;
    }

    part def IlluminationSource {
        attribute powerRating : PowerValue = 150 [W];
        attribute colorTemperature : TemperatureValue = 5500 [K];
        attribute lightType : String = "daylight";

        port lightOutput : LightOutPort;

        action generateLight {
            out light : IlluminationLight = IlluminationLight { power = 150 [W]; colorTemp = 5500 [K]; };
        }
    }

    part def FlexibleInsertionTube {
        attribute tubeLength : LengthValue = 1.2 [m];
        attribute tubeDiameter : DiameterValue = 5.5 [mm];
        attribute illuminationFiberCount : FiberCountValue = 12000;
        attribute imagingFiberCount : FiberCountValue = 18000;
        attribute currentBendAngle : AngleValue = 0 [deg];

        port lightInput : LightInPort;
        port lightOutput : LightOutPort;
        port imageInput : ImageInPort;
        port imageOutput : ImageOutPort;
        port controlInput : ControlInPort;

        action transmitLight {
            in light : IlluminationLight;
            out light : IlluminationLight;
        }

        action transmitImage {
            in image : ReflectedImage;
            out image : ReflectedImage;
        }

        action articulate {
            in command : ArticulationCommand;
            assign currentBendAngle = command.bendAngle;
        }
    }

    part def ObjectiveLensAssembly {
        attribute fieldOfView : AngleValue = 75 [deg];

        port lightInput : LightInPort;
        port imageOutput : ImageOutPort;

        action projectLight {
            in light : IlluminationLight;
        }

        action captureImage {
            out image : ReflectedImage = ReflectedImage { fieldOfView = 75 [deg]; magnification = 1; };
        }
    }

    part def ArticulationController {
        attribute maxBendAngle : AngleValue = 120 [deg];
        attribute controlType : String = "four-way lever";

        port controlOutput : ControlOutPort;

        action steerTip {
            out command : ArticulationCommand;
        }
    }

    part def EyepieceViewer {
        attribute magnification : MagnificationValue = 12;

        port imageInput : ImageInPort;

        action displayImage {
            in image : ReflectedImage;
        }
    }

    part def FiberscopeSystem {
        attribute operatorGuidesTube : Boolean = false;
        attribute targetDepthReached : Boolean = false;
        attribute viewCorrect : Boolean = false;
        attribute taskComplete : Boolean = false;
        attribute tubeFullyWithdrawn : Boolean = true;

        part illuminationSource : IlluminationSource;
        part insertionTube : FlexibleInsertionTube;
        part objectiveLens : ObjectiveLensAssembly;
        part articulationController : ArticulationController;
        part eyepiece : EyepieceViewer;

        connection lightToTube connect illuminationSource.lightOutput to insertionTube.lightInput;
        connection lightToLens connect insertionTube.lightOutput to objectiveLens.lightInput;
        connection imageToTube connect objectiveLens.imageOutput to insertionTube.imageInput;
        connection imageToEyepiece connect insertionTube.imageOutput to eyepiece.imageInput;
        connection controlToTube connect articulationController.controlOutput to insertionTube.controlInput;

        state machine OperationalStates {
            state idle;
            state inserting;
            state positioning;
            state imaging;
            state withdrawing;

            transition startInsertion from idle to inserting when operatorGuidesTube;
            transition reachTarget from inserting to positioning when targetDepthReached;
            transition achieveView from positioning to imaging when viewCorrect;
            transition finishImaging from imaging to withdrawing when taskComplete;
            transition completeWithdrawal from withdrawing to idle when tubeFullyWithdrawn;
        }
    }

    requirement def IlluminationRequirement {
        subject source : IlluminationSource;
        require source.powerRating == 150 [W];
        require source.colorTemperature == 5500 [K];
    }

    requirement def TubeDimensionRequirement {
        subject tube : FlexibleInsertionTube;
        require tube.tubeLength == 1.2 [m];
        require tube.tubeDiameter == 5.5 [mm];
    }

    requirement def ImagingFiberRequirement {
        subject tube : FlexibleInsertionTube;
        require tube.imagingFiberCount == 18000;
    }

    requirement def LensRequirement {
        subject lens : ObjectiveLensAssembly;
        require lens.fieldOfView == 75 [deg];
    }

    requirement def ArticulationRequirement {
        subject controller : ArticulationController;
        require controller.maxBendAngle == 120 [deg];
    }

    requirement def EyepieceRequirement {
        subject viewer : EyepieceViewer;
        require viewer.magnification == 12;
    }

    requirement def FiberscopeSystemRequirement {
        subject system : FiberscopeSystem;
        require system.illuminationSource.powerRating == 150 [W];
        require system.illuminationSource.colorTemperature == 5500 [K];
        require system.insertionTube.tubeLength == 1.2 [m];
        require system.insertionTube.tubeDiameter == 5.5 [mm];
        require system.insertionTube.imagingFiberCount == 18000;
        require system.objectiveLens.fieldOfView == 75 [deg];
        require system.articulationController.maxBendAngle == 120 [deg];
        require system.eyepiece.magnification == 12;
    }
}
