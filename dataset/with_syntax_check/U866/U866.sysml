package ScintillometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RefractiveIndexStructureParameter :> Real {
        doc /* Cn^2: Structure parameter of refractive index fluctuations in m^(-2/3) */
    }
    
    attribute def ScintillationIndex :> Real {
        doc /* Normalized variance of intensity fluctuations */
    }
    
    attribute def BeamWanderVariance :> Real;
    
    item def OpticalBeam {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute diameter : LengthValue;
        attribute intensity : PowerValue;
    }
    
    item def AtmosphericConditions {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
        attribute humidity : Real;
        attribute windSpeed : SpeedValue;
    }
    
    item def TurbulenceData {
        attribute timestamp : TimeValue;
        attribute cnSquared : RefractiveIndexStructureParameter;
        attribute scintillationIndex : ScintillationIndex;
        attribute sensibleHeatFlux : PowerValue;
        attribute momentumFlux : PowerValue;
    }
    
    port def OpticalOutputPort {
        out item beam : OpticalBeam;
    }
    
    port def OpticalInputPort {
        in item beam : OpticalBeam;
    }
    
    port def DataPort {
        out item data : TurbulenceData;
    }
    
    port def ControlPort {
        in item command : String;
        out item status : String;
    }
    
    part def LaserSource {
        attribute wavelength : LengthValue;
        attribute outputPower : PowerValue;
        attribute stability : Real;
        
        port laserOutput : OpticalOutputPort;
        
        action def EmitLaser {
            out emittedBeam : OpticalBeam;
        }
        
        perform action generateBeam : EmitLaser {
            out emittedBeam : OpticalBeam {
                :>> wavelength = LaserSource::wavelength;
                :>> power = LaserSource::outputPower;
            }
        }
    }
    
    part def Transmitter {
        attribute beamDivergence : Real;
        attribute aperture : LengthValue;
        
        part laser : LaserSource;
        part collimator;
        part alignmentSystem;
        
        port transmitPort : OpticalOutputPort;
        
        action def TransmitBeam {
            in sourceBeam : OpticalBeam;
            out transmittedBeam : OpticalBeam;
        }
        
        perform action transmit : TransmitBeam {
            in sourceBeam = laser.laserOutput.beam;
            out transmittedBeam;
        }
    }
    
    part def Detector {
        attribute aperture : LengthValue;
        attribute sensitivity : Real;
        attribute responseTime : TimeValue;
        attribute samplingRate : FrequencyValue;
        
        port detectorInput : OpticalInputPort;
        
        action def DetectIntensity {
            in receivedBeam : OpticalBeam;
            out intensitySignal : Real;
            out timestamp : TimeValue;
        }
    }
    
    part def Receiver {
        attribute fieldOfView : Real;
        attribute opticalFilterBandwidth : LengthValue;
        
        part detector : Detector;
        part focusingOptics;
        part signalAmplifier;
        
        port receivePort : OpticalInputPort;
        
        action def ReceiveBeam {
            in incomingBeam : OpticalBeam;
            out detectedSignal : Real;
        }
        
        perform action receive : ReceiveBeam {
            in incomingBeam;
            out detectedSignal;
        }
    }
    
    part def SignalProcessor {
        attribute processingBandwidth : FrequencyValue;
        attribute integrationPeriod : TimeValue;
        attribute filterCutoff : FrequencyValue;
        
        action def ComputeScintillationIndex {
            in intensityTimeSeries : Real[*];
            out scintIndex : ScintillationIndex;
        }
        
        action def ComputeCnSquared {
            in scintIndex : ScintillationIndex;
            in pathLength : LengthValue;
            in wavelength : LengthValue;
            out cnSquared : RefractiveIndexStructureParameter;
        }
        
        action def ComputeHeatFlux {
            in cnSquared : RefractiveIndexStructureParameter;
            in atmosphericData : AtmosphericConditions;
            out heatFlux : PowerValue;
        }
        
        action def ProcessSignals {
            in rawSignals : Real[*];
            in pathLength : LengthValue;
            in wavelength : LengthValue;
            in atmospheric : AtmosphericConditions;
            out turbulenceOutput : TurbulenceData;
        }
    }
    
    part def DataAcquisitionUnit {
        attribute bufferSize : Real;
        attribute storageCapacity : Real;
        
        port dataOutput : DataPort;
        
        action def LogData {
            in measurement : TurbulenceData;
        }
        
        action def TransmitData {
            in measurement : TurbulenceData;
            out transmittedData : TurbulenceData;
        }
    }
    
    part def Scintillometer {
        doc /* 
            A scintillometer measures atmospheric turbulence by analyzing 
            intensity fluctuations (scintillations) in an optical beam 
            propagating through the atmosphere. The system transmits a 
            coherent light beam across a known path length and detects 
            variations in received intensity caused by refractive index 
            fluctuations in the atmospheric boundary layer. From these 
            measurements, it derives the structure parameter Cn^2 and 
            calculates sensible heat flux and momentum flux for 
            meteorological and climate research applications.
        */
        
        attribute pathLength : LengthValue;
        attribute operatingWavelength : LengthValue;
        attribute measurementHeight : LengthValue;
        
        part transmitterUnit : Transmitter {
            :>> laser.wavelength = Scintillometer::operatingWavelength;
        }
        
        part receiverUnit : Receiver;
        
        part processor : SignalProcessor;
        
        part dataUnit : DataAcquisitionUnit;
        
        part atmosphericSensor {
            port environmentPort : AtmosphericConditions;
        }
        
        port controlInterface : ControlPort;
        port measurementOutput : DataPort;
        
        connection opticalPath connect 
            transmitterUnit.transmitPort to receiverUnit.receivePort;
        
        connection dataFlow connect 
            dataUnit.dataOutput to measurementOutput;
        
        state operatingMode {
            entry action initialize;
            
            state Idle {
                entry action powerDown;
            }
            
            state Calibrating {
                entry action runCalibration;
            }
            
            state Measuring {
                entry action startAcquisition;
                do action continuousMeasurement;
                exit action stopAcquisition;
            }
            
            state Fault {
                entry action logError;
            }
            
            transition first Idle
                accept at controlInterface
                then Calibrating;
            
            transition first Calibrating
                accept at controlInterface
                then Measuring;
            
            transition first Measuring
                accept at controlInterface
                then Idle;
            
            transition accept at controlInterface
                then Fault;
        }
        
        action def MeasureTurbulence {
            in pathLength : LengthValue;
            in wavelength : LengthValue;
            in atmospheric : AtmosphericConditions;
            out turbulenceData : TurbulenceData;
        }
        
        perform action operateContinuously {
            first start;
            then merge continueMeasurement;
            
            then action transmit : Transmitter::TransmitBeam {
                in sourceBeam : OpticalBeam;
                out transmittedBeam : OpticalBeam;
            }
            
            then action propagate {
                in beam = transmit.transmittedBeam;
                in conditions : AtmosphericConditions;
                out scintillatedBeam : OpticalBeam;
            }
            
            then action detect : Receiver::ReceiveBeam {
                in incomingBeam = propagate.scintillatedBeam;
                out detectedSignal : Real;
            }
            
            then action analyze : SignalProcessor::ProcessSignals {
                in rawSignals : Real[*];
                in pathLength = Scintillometer::pathLength;
                in wavelength = Scintillometer::operatingWavelength;
                in atmospheric : AtmosphericConditions;
                out turbulenceOutput : TurbulenceData;
            }
            
            then action record : DataAcquisitionUnit::LogData {
                in measurement = analyze.turbulenceOutput;
            }
            
            then action transmitData : DataAcquisitionUnit::TransmitData {
                in measurement = analyze.turbulenceOutput;
                out transmittedData : TurbulenceData;
            }
            
            then continueMeasurement;
        }
    }
    
    action def CalibrateScintillometer {
        in referenceConditions : AtmosphericConditions;
        out calibrationCoefficients : Real[*];
        
        doc /* Calibration procedure using known atmospheric conditions */
    }
    
    action def ValidateMeasurements {
        in measuredData : TurbulenceData;
        in referenceData : TurbulenceData;
        out validationResult : Boolean;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* 
            The scintillometer shall measure the refractive index structure 
            parameter Cn^2 with accuracy within 15% for values between 
            10^-15 and 10^-12 m^(-2/3) under nominal atmospheric conditions.
        */
        
        subject scintillometer : Scintillometer;
        
        require constraint accuracyConstraint {
            doc /* Cn^2 measurement error <= 15% of true value */
        }
    }
    
    requirement def PathLengthRequirement {
        doc /* 
            The system shall operate effectively over path lengths 
            from 50 meters to 5000 meters.
        */
        
        subject scintillometer : Scintillometer;
        
        require constraint pathConstraint {
            scintillometer.pathLength >= 50.0 [SI::m] and
            scintillometer.pathLength <= 5000.0 [SI::m]
        }
    }
    
    requirement def TemporalResolutionRequirement {
        doc /* 
            The system shall provide turbulence measurements at minimum 
            1 Hz sampling rate to capture atmospheric fluctuations.
        */
        
        subject scintillometer : Scintillometer;
        
        require constraint samplingConstraint {
            scintillometer.receiverUnit.detector.samplingRate >= 1.0 [SI::Hz]
        }
    }
    
    requirement def EnvironmentalOperatingRequirement {
        doc /* 
            The scintillometer shall operate in temperature range 
            -20°C to +50°C and withstand humidity up to 95% non-condensing.
        */
        
        subject scintillometer : Scintillometer;
    }
    
    requirement primaryMissionRequirement {
        doc /* 
            The scintillometer system shall measure path-averaged atmospheric 
            turbulence characteristics to enable determination of sensible 
            heat flux, momentum flux, and boundary layer structure parameters 
            for meteorological research and climate monitoring applications.
        */
        
        subject system : Scintillometer;
        
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require pathLength : PathLengthRequirement;
        require temporalResolution : TemporalResolutionRequirement;
        require environmentalOperating : EnvironmentalOperatingRequirement;
    }
    
    part deployedScintillometer : Scintillometer {
        :>> pathLength = 1000.0 [SI::m];
        :>> operatingWavelength = 880.0e-9 [SI::m];
        :>> measurementHeight = 2.0 [SI::m];
        
        :>> transmitterUnit.laser.outputPower = 5.0e-3 [SI::W];
        :>> receiverUnit.detector.samplingRate = 10.0 [SI::Hz];
        :>> processor.integrationPeriod = 60.0 [SI::s];
        
        perform action fieldMeasurement references operateContinuously;
    }
}
