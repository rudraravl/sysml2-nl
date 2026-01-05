package RainGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PrecipitationDepth :> ISQ::LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }
    
    attribute def PrecipitationRate {
        attribute num : Real;
        attribute mRef : VolumeUnit;
    }
    
    attribute def TipCount :> ScalarValues::Integer;
    
    item def Precipitation {
        attribute volume : ISQ::VolumeValue;
        attribute intensity : PrecipitationRate;
    }
    
    port def PrecipitationInputPort {
        in item precipitation : Precipitation;
    }
    
    port def MeasurementOutputPort {
        out attribute depth : PrecipitationDepth;
        out attribute rate : PrecipitationRate;
        out attribute accumulatedVolume : ISQ::VolumeValue;
    }
    
    part def CollectorFunnel {
        attribute collectionArea : ISQ::AreaValue;
        
        port precipitationIn : PrecipitationInputPort;
        port waterOut {
            out item collectedWater : Precipitation;
        }
        
        action collectPrecipitation {
            in item incomingPrecipitation : Precipitation;
            out item funnelledWater : Precipitation;
        }
    }
    
    part def TippingBucketMechanism {
        attribute bucketVolume : ISQ::VolumeValue;
        attribute tipCounter : TipCount := 0;
        attribute currentVolume : ISQ::VolumeValue := 0.0[SI::mL];
        
        port waterIn {
            in item water : Precipitation;
        }
        
        port tipSignal {
            out attribute tipOccurred : ScalarValues::Boolean;
        }
        
        state bucketOperation {
            entry; then idle;
            
            state idle;
            
            transition startFilling
                first idle
                accept waterIn.water
                then filling;
            
            state filling;
            
            transition checkCapacity
                first filling
                if currentVolume >= bucketVolume
                then tipping;
            
            state tipping;
            
            transition resetBucket
                first tipping
                then idle;
        }
    }
    
    part def MeasurementProcessor {
        attribute volumePerTip : ISQ::VolumeValue;
        attribute totalAccumulation : ISQ::VolumeValue := 0.0[SI::mL];
        attribute measuredDepth : PrecipitationDepth := 0.0[SI::mm];
        attribute measuredRate : PrecipitationRate;
        
        port tipInput {
            in attribute tipSignal : ScalarValues::Boolean;
        }
        
        port measurementOut : MeasurementOutputPort;
        
        action calculateMeasurements {
            in attribute tipReceived : ScalarValues::Boolean;
            in attribute volumePerTipValue : ISQ::VolumeValue;
            in attribute collectorArea : ISQ::AreaValue;
            in attribute timeInterval : ISQ::TimeValue;
            out attribute depthIncrement : PrecipitationDepth;
            out attribute currentRate : PrecipitationRate;
            out attribute totalVolume : ISQ::VolumeValue;
        }
    }
    
    part def DataRecorder {
        attribute recordingInterval : ISQ::TimeValue;
        
        port dataIn : MeasurementOutputPort;
        
        action recordMeasurement {
            in attribute timestamp : ISQ::TimeValue;
            in attribute depth : PrecipitationDepth;
            in attribute rate : PrecipitationRate;
            in attribute volume : ISQ::VolumeValue;
        }
    }
    
    part def RainGauge {
        doc /* 
            A rain gauge system that measures precipitation by collecting
            water through a funnel into a tipping bucket mechanism. Each
            bucket tip represents a calibrated volume, which is converted
            to precipitation depth and rate measurements for recording.
        */
        
        attribute standardBucketVolume : ISQ::VolumeValue := 5.0[SI::mL];
        attribute standardCollectionArea : ISQ::AreaValue := 100.0[SI::cm2];
        attribute measurementInterval : ISQ::TimeValue := 60.0[SI::s];
        
        part collector : CollectorFunnel {
            attribute :>> collectionArea = standardCollectionArea;
        }
        
        part tippingBucket : TippingBucketMechanism {
            attribute :>> bucketVolume = standardBucketVolume;
        }
        
        part processor : MeasurementProcessor {
            attribute :>> volumePerTip = standardBucketVolume;
        }
        
        part recorder : DataRecorder {
            attribute :>> recordingInterval = measurementInterval;
        }
        
        connection collectorToBucket connect 
            collector.waterOut to tippingBucket.waterIn;
        
        connection bucketToProcessor connect 
            tippingBucket.tipSignal to processor.tipInput;
        
        connection processorToRecorder connect 
            processor.measurementOut to recorder.dataIn;
        
        perform action operateRainGauge {
            first start;
            then merge continueMeasurement;
            
            action receivePrecipitation {
                in item precipitation : Precipitation;
            }
            
            then action funnelWater references collector.collectPrecipitation {
                in item incomingPrecipitation = receivePrecipitation.precipitation;
                out item funnelledWater;
            }
            
            then action fillBucket {
                in item water = funnelWater.funnelledWater;
            }
            
            then decide;
                if tippingBucket.currentVolume >= tippingBucket.bucketVolume then processTip;
                else continueMeasurement;
            
            action processTip {
                action triggerTip {
                    assign tippingBucket.tipCounter := tippingBucket.tipCounter + 1;
                    assign tippingBucket.currentVolume := 0.0[SI::mL];
                }
                then action computeMeasurements references processor.calculateMeasurements {
                    in attribute tipReceived = true;
                    in attribute volumePerTipValue = processor.volumePerTip;
                    in attribute collectorArea = collector.collectionArea;
                    in attribute timeInterval = measurementInterval;
                    out attribute depthIncrement;
                    out attribute currentRate;
                    out attribute totalVolume;
                }
                then action updateProcessor {
                    assign processor.totalAccumulation := computeMeasurements.totalVolume;
                    assign processor.measuredDepth := processor.measuredDepth + computeMeasurements.depthIncrement;
                }
                then action recordData references recorder.recordMeasurement {
                    in attribute timestamp = measurementInterval;
                    in attribute depth = processor.measuredDepth;
                    in attribute rate = processor.measuredRate;
                    in attribute volume = processor.totalAccumulation;
                }
            }
            
            then continueMeasurement;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The rain gauge shall measure precipitation with specified accuracy tolerance. */
        
        subject gauge : RainGauge;
        
        require constraint measurementAccuracy {
            doc /* Measurement accuracy shall be within ±2% of actual precipitation. */
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* The rain gauge shall use calibrated bucket volume for consistent measurements. */
        
        subject gauge : RainGauge;
        
        require constraint bucketCalibration {
            gauge.standardBucketVolume == 5.0[SI::mL]
        }
    }
    
    requirement def RangeRequirement {
        doc /* The rain gauge shall measure precipitation over a specified intensity range. */
        
        subject gauge : RainGauge;
        
        require constraint intensityRange {
            doc /* Shall measure precipitation rates from 0 to 300 mm/hr. */
        }
    }
    
    requirement def ResolutionRequirement {
        doc /* The rain gauge shall provide adequate measurement resolution. */
        
        subject gauge : RainGauge;
        
        require constraint depthResolution {
            doc /* Depth resolution shall be 0.5 mm or better. */
        }
    }
    
    requirement precipitationMeasurementSystem {
        doc /* 
            The rain gauge system shall accurately measure and record
            precipitation depth and intensity over time.
        */
        
        require accuracy : AccuracyRequirement;
        require calibration : CalibrationRequirement;
        require range : RangeRequirement;
        require resolution : ResolutionRequirement;
    }
}
