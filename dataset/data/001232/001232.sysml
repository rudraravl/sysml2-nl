package 'SSMIS_System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def TemperatureSensitivityValue :> Real;
    attribute def SwathWidthValue :> ISQ::LengthValue;
    attribute def DataRateValue :> Real;
    attribute def ScanAngleValue :> ISQ::PlaneAngleValue;
    
    item def BrightnessTemperatureData {
        attribute frequency : FrequencyValue;
        attribute brightnessTemp : ISQ::ThermodynamicTemperatureValue;
        attribute scanAngle : ScanAngleValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def AtmosphericProfile {
        attribute temperatureProfile : ISQ::ThermodynamicTemperatureValue[*] ordered;
        attribute humidityProfile : Real[*] ordered;
        attribute altitudeLevels : ISQ::LengthValue[*] ordered;
    }
    
    item def OceanSurfaceData {
        attribute surfaceTemp : ISQ::ThermodynamicTemperatureValue;
        attribute windSpeed : ISQ::SpeedValue;
        attribute seaIceConcentration : Real;
    }
    
    item def PrecipitationData {
        attribute rainRate : Real;
        attribute precipitationType : String;
        attribute coverage : Real;
    }
    
    item def EnvironmentalDataProduct {
        attribute atmospheric : AtmosphericProfile;
        attribute ocean : OceanSurfaceData;
        attribute precipitation : PrecipitationData;
        attribute location : ISQ::LengthValue[2];
    }
    
    attribute def CommandType;
    attribute def PowerOnCommand :> CommandType;
    attribute def ScanStartCommand :> CommandType;
    attribute def CalibrationCommand :> CommandType;
    attribute def PowerOffCommand :> CommandType;
    
    port def RadiometerOutputPort {
        out brightnessData : BrightnessTemperatureData;
    }
    
    port def ProcessorInputPort {
        in rawData : BrightnessTemperatureData;
    }
    
    port def ProcessorOutputPort {
        out environmentalData : EnvironmentalDataProduct;
    }
    
    port def DownlinkPort {
        in dataToTransmit : EnvironmentalDataProduct;
        out transmittedSignal : EnvironmentalDataProduct;
    }
    
    port def CommandInputPort {
        in command : CommandType;
    }
    
    port def PowerSupplyPort {
        out power : ISQ::PowerValue;
    }
    
    part def ConicalScanningAntenna {
        attribute diameter : ISQ::LengthValue;
        attribute scanRate : ISQ::AngularVelocityValue;
        attribute scanAngleRange : ScanAngleValue;
        
        perform action performConicalScan {
            in scanCommand : ScanStartCommand;
            out currentScanAngle : ScanAngleValue;
        }
    }
    
    part def MultichannelRadiometer {
        attribute channels : FrequencyValue[24];
        attribute temperatureSensitivity : TemperatureSensitivityValue;
        
        port radiometerOutput : RadiometerOutputPort;
        port commandInput : CommandInputPort;
        
        perform action measureBrightnessTemperature {
            in frequency : FrequencyValue;
            in scanAngle : ScanAngleValue;
            out brightnessData : BrightnessTemperatureData;
        }
    }
    
    part def CalibrationSubsystem {
        attribute hotLoadTemp : ISQ::ThermodynamicTemperatureValue;
        attribute coldLoadTemp : ISQ::ThermodynamicTemperatureValue;
        
        perform action performCalibration {
            in calibrationCmd : CalibrationCommand;
            out calibrationFactors : Real[*];
        }
    }
    
    part def SignalProcessor {
        attribute processingCapacity : DataRateValue;
        
        port processorInput : ProcessorInputPort;
        port processorOutput : ProcessorOutputPort;
        
        perform action processRadiometricData {
            in rawBrightnessData : BrightnessTemperatureData[*];
            out environmentalProducts : EnvironmentalDataProduct;
        }
    }
    
    part def DataTransmitter {
        attribute transmitPower : ISQ::PowerValue;
        attribute transmitFrequency : FrequencyValue;
        attribute dataRate : DataRateValue;
        
        port downlink : DownlinkPort;
        
        perform action transmitToGround {
            in dataProducts : EnvironmentalDataProduct;
            out transmissionSignal : EnvironmentalDataProduct;
        }
    }
    
    part def PowerManagementUnit {
        attribute solarArrayPower : ISQ::PowerValue;
        attribute batteryCapacity : ISQ::EnergyValue;
        
        port powerOutput : PowerSupplyPort;
        
        perform action managePower {
            out distributedPower : ISQ::PowerValue;
        }
    }
    
    part def ThermalControlSystem {
        attribute operatingTempMin : ISQ::ThermodynamicTemperatureValue;
        attribute operatingTempMax : ISQ::ThermodynamicTemperatureValue;
        
        perform action regulateTemperature {
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            out heatingCoolingPower : ISQ::PowerValue;
        }
    }
    
    action def AcquireMicrowaveImagery {
        in scanCmd : ScanStartCommand;
        out imageryData : BrightnessTemperatureData[*];
        
        first start;
        then action initiateScan {
            in command = scanCmd;
        }
        then action collectData {
            out rawData : BrightnessTemperatureData[*];
        }
        then action assignOutput {
            in data = collectData.rawData;
        }
        flow assignOutput.data to imageryData;
        then done;
    }
    
    action def ProcessEnvironmentalData {
        in rawImagery : BrightnessTemperatureData[*];
        out products : EnvironmentalDataProduct;
        
        first start;
        then action retrieveAtmospheric {
            in brightnessData = rawImagery;
            out atmosphericData : AtmosphericProfile;
        }
        then action retrieveOcean {
            in brightnessData = rawImagery;
            out oceanData : OceanSurfaceData;
        }
        then action retrievePrecipitation {
            in brightnessData = rawImagery;
            out precipData : PrecipitationData;
        }
        then action assembleProducts {
            in atmos = retrieveAtmospheric.atmosphericData;
            in ocean = retrieveOcean.oceanData;
            in precip = retrievePrecipitation.precipData;
            out finalProduct : EnvironmentalDataProduct;
        }
        flow assembleProducts.finalProduct to products;
        then done;
    }
    
    action def TransmitDataProducts {
        in dataProducts : EnvironmentalDataProduct;
        out downlinkSignal : EnvironmentalDataProduct;
        
        first start;
        then action formatData {
            in products = dataProducts;
            out formattedData : EnvironmentalDataProduct;
        }
        then action transmit {
            in data = formatData.formattedData;
            out signal : EnvironmentalDataProduct;
        }
        flow transmit.signal to downlinkSignal;
        then done;
    }
    
    state def SSMISOperationalMode {
        entry; then Standby;
        
        state Standby;
        state Calibration;
        state Imaging;
        state DataTransmission;
        state SafeMode;
        
        transition Standby_to_Calibration
            first Standby
            accept CalibrationCommand
            then Calibration;
            
        transition Calibration_to_Imaging
            first Calibration
            accept ScanStartCommand
            then Imaging;
            
        transition Imaging_to_DataTransmission
            first Imaging
            then DataTransmission;
            
        transition DataTransmission_to_Imaging
            first DataTransmission
            then Imaging;
            
        transition any_to_SafeMode
            first any
            accept PowerOffCommand
            then SafeMode;
    }
    
    part def SSMIS {
        doc /*
            Special Sensor Microwave Imager/Sounder (SSMIS)
            
            Primary Function:
            The SSMIS is an advanced passive microwave radiometer system designed to 
            continuously measure microwave radiation emitted and scattered by the Earth's 
            atmosphere, ocean surfaces, and land surfaces across 24 discrete frequency 
            channels ranging from 19 GHz to 183 GHz. Its primary function is to provide 
            all-weather, day-and-night environmental monitoring by converting measured 
            brightness temperatures into quantitative geophysical parameters including 
            atmospheric temperature and moisture profiles, precipitation intensity and 
            distribution, ocean surface wind speeds and temperatures, sea ice concentration 
            and extent, and soil moisture content. This multi-spectral microwave sensing 
            capability enables critical meteorological forecasting, climate monitoring, 
            and environmental research applications for defense and civilian users.
        */
        
        part antenna : ConicalScanningAntenna {
            attribute :>> diameter = 0.61[m];
            attribute :>> scanRate = 31.6[rad/s];
            attribute :>> scanAngleRange = 45.0[deg];
        }
        
        part radiometer : MultichannelRadiometer {
            attribute :>> channels = (
                19.35[GHz], 19.35[GHz], 22.235[GHz], 37.0[GHz], 37.0[GHz],
                50.3[GHz], 52.8[GHz], 53.596[GHz], 54.4[GHz], 55.5[GHz],
                57.29[GHz], 59.4[GHz], 150.0[GHz], 183.31[GHz], 183.31[GHz],
                183.31[GHz], 183.31[GHz], 183.31[GHz], 183.31[GHz], 183.31[GHz],
                91.655[GHz], 91.655[GHz], 63.283[GHz], 60.792[GHz]
            );
            attribute :>> temperatureSensitivity = 0.33;
        }
        
        part calibration : CalibrationSubsystem {
            attribute :>> hotLoadTemp = 305.0[K];
            attribute :>> coldLoadTemp = 2.7[K];
        }
        
        part processor : SignalProcessor {
            attribute :>> processingCapacity = 100.0;
        }
        
        part transmitter : DataTransmitter {
            attribute :>> transmitPower = 5.0[W];
            attribute :>> transmitFrequency = 2.25[GHz];
            attribute :>> dataRate = 52.0;
        }
        
        part powerManagement : PowerManagementUnit {
            attribute :>> solarArrayPower = 150.0[W];
            attribute :>> batteryCapacity = 500.0[W*h];
        }
        
        part thermalControl : ThermalControlSystem {
            attribute :>> operatingTempMin = 263.15[K];
            attribute :>> operatingTempMax = 313.15[K];
        }
        
        attribute operationalMode : SSMISOperationalMode;
        attribute swathWidth : SwathWidthValue = 1707.0[km];
        
        connection radiometerToProcessor connect 
            radiometer.radiometerOutput to processor.processorInput;
            
        connection processorToTransmitter connect 
            processor.processorOutput to transmitter.downlink;
        
        perform action operateSSMIS {
            first start;
            then action powerUp : PowerManagementUnit::managePower;
            then action calibrate : CalibrationSubsystem::performCalibration;
            then merge continuousOperation;
            
            action continuousOperation {
                loop {
                    action acquireImagery : AcquireMicrowaveImagery {
                        out imageryData : BrightnessTemperatureData[*];
                    }
                    
                    flow acquireImagery.imageryData to processData.rawImagery;
                    
                    action processData : ProcessEnvironmentalData {
                        in rawImagery : BrightnessTemperatureData[*];
                        out products : EnvironmentalDataProduct;
                    }
                    
                    flow processData.products to transmitProducts.dataProducts;
                    
                    action transmitProducts : TransmitDataProducts {
                        in dataProducts : EnvironmentalDataProduct;
                        out downlinkSignal : EnvironmentalDataProduct;
                    }
                }
            }
        }
    }
    
    requirement def MissionRequirement;
    requirement def PerformanceRequirement :> MissionRequirement;
    requirement def OperationalRequirement :> MissionRequirement;
    
    requirement <'SSMIS-REQ-001'> continuousEnvironmentalMonitoring : MissionRequirement {
        doc /*
            The SSMIS shall provide continuous all-weather monitoring of atmospheric,
            oceanic, and terrestrial environmental parameters to support meteorological
            forecasting and climate research.
        */
        subject ssmisSystem : SSMIS;
    }
    
    requirement <'SSMIS-REQ-002'> multispectralCapability : PerformanceRequirement {
        doc /*
            The system shall measure brightness temperatures across 24 microwave
            frequency channels spanning 19 GHz to 183 GHz.
        */
        subject radiometer : MultichannelRadiometer;
        
        require constraint channelCountConstraint {
            radiometer.channels->size() == 24
        }
    }
    
    requirement <'SSMIS-REQ-003'> temperatureSensitivity : PerformanceRequirement {
        doc /*
            The system shall achieve brightness temperature sensitivity of 0.33 K
            or better for atmospheric sounding channels.
        */
        subject radiometer : MultichannelRadiometer;
        
        require constraint sensitivityConstraint {
            radiometer.temperatureSensitivity <= 0.33
        }
    }
    
    requirement <'SSMIS-REQ-004'> swathCoverage : PerformanceRequirement {
        doc /*
            The system shall provide a continuous swath width of at least 1700 km
            to enable global coverage within 12 hours.
        */
        subject ssmisSystem : SSMIS;
        
        require constraint swathConstraint {
            ssmisSystem.swathWidth >= 1700.0[km]
        }
    }
    
    requirement <'SSMIS-REQ-005'> dataTransmissionRate : PerformanceRequirement {
        doc /*
            The system shall transmit processed environmental data products to
            ground stations at a minimum rate of 50 Mbps.
        */
        subject transmitter : DataTransmitter;
        
        require constraint dataRateConstraint {
            transmitter.dataRate >= 50.0
        }
    }
    
    requirement <'SSMIS-REQ-006'> allWeatherOperation : OperationalRequirement {
        doc /*
            The system shall operate continuously in all weather conditions
            including clouds, precipitation, and darkness.
        */
        subject ssmisSystem : SSMIS;
    }
    
    part ssmisSystem : SSMIS {
        satisfy continuousEnvironmentalMonitoring;
        satisfy multispectralCapability by radiometer;
        satisfy temperatureSensitivity by radiometer;
        satisfy swathCoverage;
        satisfy dataTransmissionRate by transmitter;
        satisfy allWeatherOperation;
    }
}
