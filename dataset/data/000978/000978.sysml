package AtomicForceMicroscopySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ScanMode {
        attribute contactMode : Boolean;
        attribute tappingMode : Boolean;
        attribute nonContactMode : Boolean;
    }
    
    attribute def SamplePosition {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def DeflectionData {
        attribute verticalDeflection : LengthValue;
        attribute lateralDeflection : LengthValue;
    }
    
    attribute def ForceData {
        attribute normalForce : ForceValue;
        attribute lateralForce : ForceValue;
    }
    
    attribute def ImageData {
        attribute resolution : Integer;
        attribute heightMap : Real[*];
        attribute scanArea : AreaValue;
    }
    
    attribute def ScanParameters {
        attribute scanRate : FrequencyValue;
        attribute scanLines : Integer;
        attribute setPoint : ForceValue;
    }
    
    port def LaserPort {
        out laserBeam : PowerValue;
    }
    
    port def DeflectionPort {
        in deflectionSignal : DeflectionData;
    }
    
    port def PiezoControlPort {
        out controlVoltage : Real;
        in positionFeedback : SamplePosition;
    }
    
    port def DataPort {
        out imageData : ImageData;
        out forceData : ForceData;
    }
    
    part def Cantilever {
        attribute springConstant : Real;
        attribute resonantFrequency : FrequencyValue;
        attribute tipRadius : LengthValue;
        
        port tipPort {
            out tipForce : ForceValue;
            in sampleInteraction : ForceValue;
        }
        
        port deflectionPort : DeflectionPort;
    }
    
    part def LaserSystem {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        
        port laserOutput : LaserPort;
    }
    
    part def Photodetector {
        attribute sensitivity : Real;
        attribute quadrants : Integer;
        
        port laserInput {
            in reflectedBeam : PowerValue;
        }
        
        port signalOutput : DeflectionPort;
    }
    
    part def PiezoScanner {
        attribute maxXRange : LengthValue;
        attribute maxYRange : LengthValue;
        attribute maxZRange : LengthValue;
        attribute resolution : LengthValue;
        
        port controlInput : PiezoControlPort;
        
        port sampleStage {
            out samplePosition : SamplePosition;
        }
    }
    
    part def FeedbackController {
        attribute proportionalGain : Real;
        attribute integralGain : Real;
        attribute derivativeGain : Real;
        
        port errorInput {
            in setPoint : ForceValue;
            in measuredDeflection : DeflectionData;
        }
        
        port controlOutput : PiezoControlPort;
    }
    
    part def DataAcquisitionSystem {
        attribute samplingRate : FrequencyValue;
        attribute bufferSize : Integer;
        
        port deflectionInput : DeflectionPort;
        port positionInput {
            in position : SamplePosition;
        }
        port dataOutput : DataPort;
    }
    
    part def Sample {
        attribute surfaceTopography : Real[*];
        attribute mechanicalProperties : Real;
        
        port surfacePort {
            in probingForce : ForceValue;
            out surfaceResponse : ForceValue;
        }
    }
    
    action def InitializeSystem {
        in scanMode : ScanMode;
        in scanParams : ScanParameters;
        out systemReady : Boolean;
    }
    
    action def ApproachSurface {
        in initialPosition : SamplePosition;
        in approachSpeed : Real;
        out contactDetected : Boolean;
        out finalPosition : SamplePosition;
    }
    
    action def MeasureDeflection {
        in laserPower : PowerValue;
        out deflection : DeflectionData;
    }
    
    action def CalculateForce {
        in deflection : DeflectionData;
        in springConstant : Real;
        out force : ForceData;
    }
    
    action def AdjustHeight {
        in currentDeflection : DeflectionData;
        in setPoint : ForceValue;
        out zAdjustment : LengthValue;
    }
    
    action def ScanLine {
        in startPosition : SamplePosition;
        in endPosition : SamplePosition;
        in scanRate : FrequencyValue;
        out lineData : Real[*];
    }
    
    action def ProcessImage {
        in rawData : Real[*];
        in scanParams : ScanParameters;
        out processedImage : ImageData;
    }
    
    action def PerformAFMScan {
        in scanMode : ScanMode;
        in scanParams : ScanParameters;
        out imageData : ImageData;
        out forceData : ForceData;
        
        attribute scanComplete : Boolean;
        
        first start;
        then action initialize : InitializeSystem {
            in scanMode = PerformAFMScan::scanMode;
            in scanParams = PerformAFMScan::scanParams;
            out systemReady : Boolean;
        }
        then action approach : ApproachSurface {
            in initialPosition : SamplePosition;
            in approachSpeed : Real;
            out contactDetected : Boolean;
            out finalPosition : SamplePosition;
        }
        then merge scanLoop;
        then decide;
            if PerformAFMScan::scanComplete then processData;
            if !PerformAFMScan::scanComplete then continueScan;
        
        action continueScan {
            action measureDeflection : MeasureDeflection {
                in laserPower : PowerValue;
                out deflection : DeflectionData;
            }
            flow measureDeflection.deflection to calculateForce.deflection;
            
            action calculateForce : CalculateForce {
                in deflection : DeflectionData;
                in springConstant : Real;
                out force : ForceData;
            }
            flow calculateForce.force to adjustHeight.currentDeflection;
            
            action adjustHeight : AdjustHeight {
                in currentDeflection : DeflectionData;
                in setPoint : ForceValue;
                out zAdjustment : LengthValue;
            }
            flow adjustHeight.zAdjustment to scanLine.startPosition;
            
            action scanLine : ScanLine {
                in startPosition : SamplePosition;
                in endPosition : SamplePosition;
                in scanRate : FrequencyValue;
                out lineData : Real[*];
            }
        }
        then scanLoop;
        
        action processData : ProcessImage {
            in rawData : Real[*];
            in scanParams = PerformAFMScan::scanParams;
            out processedImage : ImageData;
        }
        then done;
    }
    
    part atomicForceMicroscope {
        attribute operatingMode : ScanMode;
        
        part laser : LaserSystem {
            attribute :>> wavelength = 650 [SI::nm];
            attribute :>> power = 5e-3 [SI::W];
        }
        
        part cantilever : Cantilever {
            attribute :>> springConstant = 0.2;
            attribute :>> resonantFrequency = 70000 [SI::Hz];
            attribute :>> tipRadius = 10 [SI::nm];
        }
        
        part photodetector : Photodetector {
            attribute :>> sensitivity = 0.95;
            attribute :>> quadrants = 4;
        }
        
        part piezoScanner : PiezoScanner {
            attribute :>> maxXRange = 100e-6 [SI::m];
            attribute :>> maxYRange = 100e-6 [SI::m];
            attribute :>> maxZRange = 15e-6 [SI::m];
            attribute :>> resolution = 0.1 [SI::nm];
        }
        
        part feedbackController : FeedbackController {
            attribute :>> proportionalGain = 0.5;
            attribute :>> integralGain = 0.1;
            attribute :>> derivativeGain = 0.05;
        }
        
        part dataAcquisition : DataAcquisitionSystem {
            attribute :>> samplingRate = 100000 [SI::Hz];
            attribute :>> bufferSize = 1024;
        }
        
        part sample : Sample;
        
        connect laser.laserOutput to cantilever.deflectionPort;
        connect cantilever.deflectionPort to photodetector.laserInput;
        connect photodetector.signalOutput to feedbackController.errorInput;
        connect feedbackController.controlOutput to piezoScanner.controlInput;
        connect piezoScanner.sampleStage to sample.surfacePort;
        connect cantilever.tipPort to sample.surfacePort;
        connect photodetector.signalOutput to dataAcquisition.deflectionInput;
        connect piezoScanner.controlInput to dataAcquisition.positionInput;
        
        perform action afmScan : PerformAFMScan {
            in scanMode = atomicForceMicroscope.operatingMode;
            in scanParams : ScanParameters;
            out imageData : ImageData;
            out forceData : ForceData;
        }
    }
    
    requirement def <'AFM-001'> SpatialResolutionRequirement {
        doc /* The AFM system shall achieve atomic-scale spatial resolution 
                better than 1 nanometer in the lateral direction. */
        
        require constraint {
            atomicForceMicroscope.cantilever.tipRadius < 20 [SI::nm]
        }
    }
    
    requirement def <'AFM-002'> ForceResolutionRequirement {
        doc /* The AFM system shall measure forces with a resolution 
                better than 10 piconewtons. */
        
        require constraint {
            atomicForceMicroscope.cantilever.springConstant * 
            atomicForceMicroscope.piezoScanner.resolution < 10e-12 [SI::N]
        }
    }
    
    requirement def <'AFM-003'> ScanRangeRequirement {
        doc /* The AFM system shall provide a minimum scan range 
                of 100 micrometers in X and Y directions. */
        
        require constraint {
            atomicForceMicroscope.piezoScanner.maxXRange >= 100e-6 [SI::m] and
            atomicForceMicroscope.piezoScanner.maxYRange >= 100e-6 [SI::m]
        }
    }
    
    requirement <'AFM-MISSION'> performSurfaceImaging {
        doc /* The AFM system shall acquire high-resolution topographical 
                and mechanical property maps of sample surfaces at the nanoscale 
                by precisely controlling probe-sample interaction forces. */
        
        assume constraint validScanMode {
            atomicForceMicroscope.operatingMode.contactMode or
            atomicForceMicroscope.operatingMode.tappingMode or
            atomicForceMicroscope.operatingMode.nonContactMode
        }
        
        require spatialReq : SpatialResolutionRequirement;
        require forceReq : ForceResolutionRequirement;
        require scanReq : ScanRangeRequirement;
    }
}
