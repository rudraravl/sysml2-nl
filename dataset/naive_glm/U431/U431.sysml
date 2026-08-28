package UCT_System {

    package Units {
        unit m;
        unit s;
        unit kg;
        unit K;
        unit V;
        unit Hz;
        unit Pa;
        unit W;
        unit deg;
        unit px;
        unit 'm/s';
        unit 'Gb/s';
        unit 'm^3';
    }

    package ValueTypes {
        import Units::*;

        value type DistanceValue { unit m; }
        value type AngleValue { unit deg; }
        value type FrequencyValue { unit Hz; }
        value type VoltageValue { unit V; }
        value type TimeValue { unit s; }
        value type PowerValue { unit W; }
        value type TemperatureValue { unit K; }
        value type PressureValue { unit Pa; }
        value type SpeedValue { unit 'm/s'; }
        value type DataRateValue { unit 'Gb/s'; }
        value type PixelValue { unit px; }
        value type MassValue { unit kg; }
        value type VolumeValue { unit 'm^3'; }
    }

    package Items {
        import ValueTypes::*;

        item def ScanCommand {
            attribute scanId : String;
            attribute targetSliceDepth : DistanceValue;
            attribute resolution : PixelValue;
            attribute projectionCount : Integer;
        }

        item def ScanStatus {
            attribute currentState : String;
            attribute progress : Real;
            attribute projectionsAcquired : Integer;
            attribute totalProjections : Integer;
            attribute errors : String[0..*];
        }

        item def UltrasoundPulse {
            attribute frequency : FrequencyValue;
            attribute amplitude : VoltageValue;
            attribute duration : TimeValue;
            attribute focusDepth : DistanceValue;
        }

        item def EchoSignal {
            attribute voltage : VoltageValue;
            attribute timestamp : TimeValue;
            attribute angle : AngleValue;
            attribute elementId : Integer;
        }

        item def ProjectionData {
            attribute angle : AngleValue;
            attribute samples : VoltageValue[0..*];
            attribute gain : Real;
            attribute timestamp : TimeValue;
        }

        item def ProcessedProjection {
            attribute angle : AngleValue;
            attribute filteredSamples : Real[0..*];
            attribute snr : Real;
            attribute projectionIndex : Integer;
        }

        item def TomographicImage {
            attribute sliceId : String;
            attribute pixels : Real[0..*];
            attribute width : PixelValue;
            attribute height : PixelValue;
            attribute sliceDepth : DistanceValue;
            attribute reconstructionTime : TimeValue;
        }

        item def DisplayedImage {
            attribute image : TomographicImage;
            attribute windowLevel : Real;
            attribute windowWidth : Real;
            attribute zoom : Real;
        }

        item def ControlCommand {
            attribute command : String;
            attribute timestamp : TimeValue;
        }

        item def RotationCommand {
            attribute targetAngle : AngleValue;
            attribute rotationSpeed : SpeedValue;
        }

        item def PositionCommand {
            attribute lateral : DistanceValue;
            attribute vertical : DistanceValue;
            attribute longitudinal : DistanceValue;
        }

        item def CouplingMedium {
            attribute temperature : TemperatureValue;
            attribute degasLevel : Real;
            attribute volume : VolumeValue;
        }

        item def RingTrigger {
            attribute pulseParams : UltrasoundPulse;
            attribute elementGroup : Integer;
        }

        item def EchoReadySignal {
            attribute ready : Boolean;
            attribute elementCount : Integer;
        }

        item def PositionReachedSignal {
            attribute reached : Boolean;
            attribute finalLateral : DistanceValue;
            attribute finalVertical : DistanceValue;
            attribute finalLongitudinal : DistanceValue;
        }
    }

    package Ports {
        import Items::*;

        port def ScanCommandPort {
            in item cmd : ScanCommand;
            out item ack : ScanStatus;
        }

        port def RotationControlPort {
            in item rotCmd : RotationCommand;
            out item angleReached : AngleValue;
        }

        port def RingControlPort {
            in item trigger : RingTrigger;
            out item echoReady : EchoReadySignal;
        }

        port def RawDataPort {
            out item raw : EchoSignal;
        }

        port def ProjectionPort {
            out item projection : ProjectionData;
        }

        port def ProcessedProjectionPort {
            out item processed : ProcessedProjection;
        }

        port def ImagePort {
            out item image : TomographicImage;
        }

        port def DisplayPort {
            out item displayed : DisplayedImage;
        }

        port def PositionControlPort {
            in item posCmd : PositionCommand;
            out item positionReached : PositionReachedSignal;
        }

        port def StatusPort {
            out item status : ScanStatus;
        }

        port def AcousticPort {
            out item pulse : UltrasoundPulse;
            in item echo : EchoSignal;
        }
    }

    package Components {
        import Ports::*;
        import Items::*;
        import ValueTypes::*;

        part def UltrasoundElement {
            doc /* Single ultrasound transducer element within the ring array */
            attribute elementId : Integer;
            attribute centerFrequency : FrequencyValue;
            attribute bandwidth : FrequencyValue;
            attribute active : Boolean;
            port acoustic : AcousticPort;
        }

        part def TransducerRing {
            doc /* Ring array of ultrasound elements for transmitting pulses and receiving echoes */
            attribute ringId : String;
            attribute elementCount : Integer;
            attribute ringDiameter : DistanceValue;
            attribute centerFrequency : FrequencyValue;
            attribute elementPitch : DistanceValue;

            part elements : UltrasoundElement[1..*];

            port ringControl : RingControlPort;
            port rawData : RawDataPort;

            attribute triggerReceived : Boolean;
            attribute echoCaptured : Boolean;
            attribute dataSent : Boolean;

            exhibit state machine RingOperation {
                state Idle;
                state Transmitting;
                state Receiving;
                state DataReady;

                transition t1 Idle -> Transmitting when triggerReceived;
                transition t2 Transmitting -> Receiving after 0.0001 [s];
                transition t3 Receiving -> DataReady when echoCaptured;
                transition t4 DataReady -> Idle when dataSent;
            }
        }

        part def CouplingMediumTank {
            doc /* Tank holding degassed water for acoustic coupling between transducers and patient */
            attribute tankId : String;
            attribute capacity : VolumeValue;
            attribute medium : CouplingMedium;
            attribute currentTemp : TemperatureValue;
            attribute heaterPower : PowerValue;
            attribute degasserActive : Boolean;

            attribute degasLow : Boolean;
            attribute degasComplete : Boolean;
            attribute tempInRange : Boolean;
            attribute scanActive : Boolean;
            attribute scanComplete : Boolean;

            exhibit state machine TankMaintenance {
                state Filled;
                state Degassing;
                state Heating;
                state Ready;
                state Monitoring;

                transition t1 Filled -> Degassing when degasLow;
                transition t2 Degassing -> Heating when degasComplete;
                transition t3 Heating -> Ready when tempInRange;
                transition t4 Ready -> Monitoring when scanActive;
                transition t5 Monitoring -> Degassing when degasLow;
                transition t6 Monitoring -> Ready when scanComplete;
            }
        }

        part def RotationalGantry {
            doc /* Rotating structure that holds the transducer ring and positions it at multiple angles */
            attribute gantryId : String;
            attribute currentAngle : AngleValue;
            attribute angularSpeed : SpeedValue;
            attribute stepIncrement : AngleValue;
            attribute maxSpeed : SpeedValue;
            attribute motorPower : PowerValue;

            port rotationControl : RotationControlPort;

            attribute rotationCommanded : Boolean;
            attribute angleReachedFlag : Boolean;
            attribute angleConfirmed : Boolean;
            attribute nextIncrement : Boolean;
            attribute scanComplete : Boolean;

            exhibit state machine GantryMotion {
                state AtRest;
                state Rotating;
                state AtAngle;
                state Holding;

                transition t1 AtRest -> Rotating when rotationCommanded;
                transition t2 Rotating -> AtAngle when angleReachedFlag;
                transition t3 AtAngle -> Holding when angleConfirmed;
                transition t4 Holding -> Rotating when nextIncrement;
                transition t5 Holding -> AtRest when scanComplete;
            }
        }

        part def PatientPositioningTable {
            doc /* Motorized table for placing the subject correctly within the scanner gantry */
            attribute tableId : String;
            attribute maxLoad : MassValue;
            attribute currentLateral : DistanceValue;
            attribute currentVertical : DistanceValue;
            attribute currentLongitudinal : DistanceValue;
            attribute motorPower : PowerValue;

            port positionControl : PositionControlPort;

            attribute patientDetected : Boolean;
            attribute loadStable : Boolean;
            attribute positionCommanded : Boolean;
            attribute targetReached : Boolean;
            attribute scanInitiated : Boolean;
            attribute scanComplete : Boolean;
            attribute patientReleased : Boolean;

            exhibit state machine PositioningBehavior {
                state Unloaded;
                state Loading;
                state Loaded;
                state Positioning;
                state Positioned;
                state Scanning;

                transition t1 Unloaded -> Loading when patientDetected;
                transition t2 Loading -> Loaded when loadStable;
                transition t3 Loaded -> Positioning when positionCommanded;
                transition t4 Positioning -> Positioned when targetReached;
                transition t5 Positioned -> Scanning when scanInitiated;
                transition t6 Scanning -> Positioned when scanComplete;
                transition t7 Positioned -> Unloaded when patientReleased;
            }
        }

        part def AcquisitionController {
            doc /* Central coordinator that manages the entire scan procedure from command to completion */
            attribute controllerId : String;
            attribute totalProjections : Integer;
            attribute currentProjection : Integer;
            attribute angularRange : AngleValue;
            attribute angularStep : AngleValue;
            attribute processingTimeout : TimeValue;

            port scanCommand : ScanCommandPort;
            port gantryRotation : ~RotationControlPort;
            port ringControl : ~RingControlPort;
            port tableControl : ~PositionControlPort;
            port statusOut : StatusPort;

            attribute commandReceived : Boolean;
            attribute systemReady : Boolean;
            attribute gantryAtStart : Boolean;
            attribute gantryAtAngle : Boolean;
            attribute projectionStored : Boolean;
            attribute moreProjections : Boolean;
            attribute allProjectionsDone : Boolean;
            attribute dataTransferred : Boolean;

            exhibit state machine AcquisitionSequence {
                state Idle;
                state Ready;
                state Initializing;
                state Scanning;
                state AcquiringProjection;
                state IncrementingAngle;
                state ScanComplete;

                transition t1 Idle -> Ready when commandReceived;
                transition t2 Ready -> Initializing when systemReady;
                transition t3 Initializing -> Scanning when gantryAtStart;
                transition t4 Scanning -> AcquiringProjection when gantryAtAngle;
                transition t5 AcquiringProjection -> IncrementingAngle when projectionStored;
                transition t6 IncrementingAngle -> AcquiringProjection when moreProjections;
                transition t7 IncrementingAngle -> ScanComplete when allProjectionsDone;
                transition t8 ScanComplete -> Ready when dataTransferred;
            }
        }

        part def SignalProcessingUnit {
            doc /* Filters noise and amplifies raw echo signals into clean projection data */
            attribute spuId : String;
            attribute filterType : String;
            attribute filterCutoff : FrequencyValue;
            attribute gainFactor : Real;
            attribute samplingRate : FrequencyValue;
            attribute dataRate : DataRateValue;

            port rawDataIn : ~RawDataPort;
            port projectionOut : ProjectionPort;
            port processedOut : ProcessedProjectionPort;

            attribute rawDataReceived : Boolean;
            attribute noiseRemoved : Boolean;
            attribute gainApplied : Boolean;
            attribute projectionSent : Boolean;
            attribute processedSent : Boolean;

            exhibit state machine ProcessingBehavior {
                state Waiting;
                state Filtering;
                state Amplifying;
                state Packaging;
                state Done;

                transition t1 Waiting -> Filtering when rawDataReceived;
                transition t2 Filtering -> Amplifying when noiseRemoved;
                transition t3 Amplifying -> Packaging when gainApplied;
                transition t4 Packaging -> Done when projectionSent;
                transition t5 Done -> Waiting when processedSent;
            }
        }

        part def ReconstructionProcessor {
            doc /* High-performance processor that combines all projections into a tomographic image using FBP */
            attribute rpId : String;
            attribute algorithm : String;
            attribute sliceWidth : PixelValue;
            attribute sliceHeight : PixelValue;
            attribute processingTime : TimeValue;
            attribute coreCount : Integer;
            attribute memoryGB : Integer;

            port projectionsIn : ~ProcessedProjectionPort;
            port imageOut : ImagePort;

            attribute firstProjectionReceived : Boolean;
            attribute allProjectionsReceived : Boolean;
            attribute reconstructionComplete : Boolean;
            attribute filterApplied : Boolean;
            attribute imageSent : Boolean;

            exhibit state machine ReconstructionBehavior {
                state Idle;
                state CollectingProjections;
                state BackProjecting;
                state FilteringImage;
                state ImageReady;

                transition t1 Idle -> CollectingProjections when firstProjectionReceived;
                transition t2 CollectingProjections -> BackProjecting when allProjectionsReceived;
                transition t3 BackProjecting -> FilteringImage when reconstructionComplete;
                transition t4 FilteringImage -> ImageReady when filterApplied;
                transition t5 ImageReady -> Idle when imageSent;
            }
        }

        part def ImagingWorkstation {
            doc /* Operator console for initiating scans, viewing, analyzing, and storing reconstructed images */
            attribute wsId : String;
            attribute displayResolution : PixelValue;
            attribute storageGB : Integer;
            attribute osVersion : String;
            attribute pacsConnected : Boolean;

            port scanCommandOut : ~ScanCommandPort;
            port displayIn : ~ImagePort;
            port displayOut : DisplayPort;
            port statusIn : ~StatusPort;

            attribute poweredOn : Boolean;
            attribute scanInitiated : Boolean;
            attribute commandSent : Boolean;
            attribute ackReceived : Boolean;
            attribute imageReceived : Boolean;
            attribute analysisRequested : Boolean;
            attribute analysisComplete : Boolean;
            attribute imageStored : Boolean;

            exhibit state machine WorkstationBehavior {
                state Offline;
                state Online;
                state Commanding;
                state Waiting;
                state Displaying;
                state Analyzing;
                state Storing;

                transition t1 Offline -> Online when poweredOn;
                transition t2 Online -> Commanding when scanInitiated;
                transition t3 Commanding -> Waiting when commandSent;
                transition t4 Waiting -> Online when ackReceived;
                transition t5 Online -> Displaying when imageReceived;
                transition t6 Displaying -> Analyzing when analysisRequested;
                transition t7 Analyzing -> Storing when analysisComplete;
                transition t8 Storing -> Online when imageStored;
            }
        }
    }

    package System {
        import Components::*;
        import Ports::*;
        import Items::*;
        import ValueTypes::*;

        part def UCTScanner {
            doc /* Ultrasound Computer Tomography system for non-invasive high-resolution cross-sectional imaging */
            attribute systemId : String;
            attribute manufacturer : String;
            attribute model : String;
            attribute serialNumber : String;
            attribute installDate : String;

            attribute systemInitialized : Boolean;
            attribute scanCommandReceived : Boolean;
            attribute allProjectionsAcquired : Boolean;
            attribute imageReconstructed : Boolean;
            attribute imageDisplayedAndStored : Boolean;

            part positioningTable : PatientPositioningTable;
            part gantry : RotationalGantry;
            part transducerRing : TransducerRing;
            part couplingTank : CouplingMediumTank;
            part acquisitionController : AcquisitionController;
            part signalProcessor : SignalProcessingUnit;
            part reconstructionProcessor : ReconstructionProcessor;
            part workstation : ImagingWorkstation;

            connection c1 connect workstation.scanCommandOut to acquisitionController.scanCommand;
            connection c2 connect acquisitionController.gantryRotation to gantry.rotationControl;
            connection c3 connect acquisitionController.ringControl to transducerRing.ringControl;
            connection c4 connect acquisitionController.tableControl to positioningTable.positionControl;
            connection c5 connect transducerRing.rawData to signalProcessor.rawDataIn;
            connection c6 connect signalProcessor.processedOut to reconstructionProcessor.projectionsIn;
            connection c7 connect reconstructionProcessor.imageOut to workstation.displayIn;
            connection c8 connect acquisitionController.statusOut to workstation.statusIn;

            exhibit state machine SystemOperation {
                state Idle;
                state Ready;
                state Scanning;
                state Reconstructing;
                state Displaying;

                transition t1 Idle -> Ready when systemInitialized;
                transition t2 Ready -> Scanning when scanCommandReceived;
                transition t3 Scanning -> Reconstructing when allProjectionsAcquired;
                transition t4 Reconstructing -> Displaying when imageReconstructed;
                transition t5 Displaying -> Ready when imageDisplayedAndStored;
            }
        }
    }

    package Requirements {
        import ValueTypes::*;

        requirement def SystemRequirement {
            attribute reqId : String;
            attribute text : String;
        }

        requirement NonInvasiveImaging :> SystemRequirement {
            attribute reqId : String = "REQ-001";
            attribute text : String = "The system shall produce non-invasive cross-sectional images using sound waves instead of X-rays.";
        }

        requirement HighResolution :> SystemRequirement {
            attribute reqId : String = "REQ-002";
            attribute text : String = "The system shall achieve spatial resolution of at least 1 mm for soft tissue imaging.";
            attribute minResolution : DistanceValue = 0.001;
        }

        requirement FullRotation :> SystemRequirement {
            attribute reqId : String = "REQ-003";
            attribute text : String = "The system shall acquire projection data over a full 360 degree rotation around the patient.";
            attribute totalAngle : AngleValue = 360;
        }

        requirement RealTimeDisplay :> SystemRequirement {
            attribute reqId : String = "REQ-004";
            attribute text : String = "The system shall display the reconstructed image within 30 seconds of scan completion.";
            attribute maxDisplayTime : TimeValue = 30;
        }

        requirement CouplingMediumIntegrity :> SystemRequirement {
            attribute reqId : String = "REQ-005";
            attribute text : String = "The coupling medium shall be degassed water maintained between 37 and 40 degrees Celsius.";
            attribute minTemp : TemperatureValue = 310.15;
            attribute maxTemp : TemperatureValue = 313.15;
        }

        requirement PatientSafety :> SystemRequirement {
            attribute reqId : String = "REQ-006";
            attribute text : String = "The patient positioning table shall support a minimum load of 200 kg safely.";
            attribute minLoad : MassValue = 200;
        }

        requirement ImageReconstruction :> SystemRequirement {
            attribute reqId : String = "REQ-007";
            attribute text : String = "The reconstruction processor shall use a Filtered Back-Projection algorithm to combine all projection data into a tomographic slice.";
            attribute algorithm : String = "FilteredBackProjection";
        }

        requirement GantryPrecision :> SystemRequirement {
            attribute reqId : String = "REQ-008";
            attribute text : String = "The rotational gantry shall position the transducer ring with angular precision of at least 1 degree per step.";
            attribute maxAngularError : AngleValue = 1;
        }

        requirement SignalProcessing :> SystemRequirement {
            attribute reqId : String = "REQ-009";
            attribute text : String = "The signal processing unit shall filter noise and amplify raw echo signals before reconstruction.";
        }

        requirement SystemStates :> SystemRequirement {
            attribute reqId : String = "REQ-010";
            attribute text : String = "The system shall operate through distinct states: idle, ready, scanning, reconstructing, and displaying, returning to ready after each scan.";
        }

        requirement ProjectionIncrement :> SystemRequirement {
            attribute reqId : String = "REQ-011";
            attribute text : String = "The gantry shall rotate by a small angular increment between projections and repeat transmit-receive-process until a full circle is captured.";
            attribute angularStep : AngleValue = 1;
        }

        requirement ImageStorage :> SystemRequirement {
            attribute reqId : String = "REQ-012";
            attribute text : String = "The imaging workstation shall store reconstructed images for subsequent review and analysis by medical professionals.";
        }
    }

    package Allocations {
        import Requirements::*;
        import Components::*;
        import System::*;

        allocation def SystemAllocation;

        allocation a1 :> SystemAllocation allocate NonInvasiveImaging to UCTScanner;
        allocation a2 :> SystemAllocation allocate HighResolution to UCTScanner;
        allocation a3 :> SystemAllocation allocate FullRotation to UCTScanner;
        allocation a4 :> SystemAllocation allocate RealTimeDisplay to UCTScanner;
        allocation a5 :> SystemAllocation allocate CouplingMediumIntegrity to CouplingMediumTank;
        allocation a6 :> SystemAllocation allocate PatientSafety to PatientPositioningTable;
        allocation a7 :> SystemAllocation allocate ImageReconstruction to ReconstructionProcessor;
        allocation a8 :> SystemAllocation allocate GantryPrecision to RotationalGantry;
        allocation a9 :> SystemAllocation allocate SignalProcessing to SignalProcessingUnit;
        allocation a10 :> SystemAllocation allocate SystemStates to UCTScanner;
        allocation a11 :> SystemAllocation allocate ProjectionIncrement to AcquisitionController;
        allocation a12 :> SystemAllocation allocate ImageStorage to ImagingWorkstation;
    }
}
