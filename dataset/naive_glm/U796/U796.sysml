package OptodeSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Units =====
    unit mg_per_L;
    unit degC;
    unit bar;
    unit lux;
    unit us;
    unit V;
    unit mA;
    unit s;
    unit nm;
    unit m;
    unit dB_per_m;
    unit Hz;

    // ===== Value Types =====
    value type OxygenConcentration :> Real {
        :> unit = mg_per_L;
    }
    value type Temperature :> Real {
        :> unit = degC;
    }
    value type Pressure :> Real {
        :> unit = bar;
    }
    value type LightIntensity :> Real {
        :> unit = lux;
    }
    value type DecayTime :> Real {
        :> unit = us;
    }
    value type Voltage :> Real {
        :> unit = V;
    }
    value type ElectricCurrent :> Real {
        :> unit = mA;
    }
    value type TimeStamp :> Real {
        :> unit = s;
    }
    value type Wavelength :> Real {
        :> unit = nm;
    }
    value type Length :> Real {
        :> unit = m;
    }
    value type Attenuation :> Real {
        :> unit = dB_per_m;
    }
    value type Frequency :> Real {
        :> unit = Hz;
    }

    // ===== Items =====
    item def BlueLight {
        attribute wavelength : Wavelength = 470;
        attribute intensity : LightIntensity;
    }

    item def FluorescentEmission {
        attribute wavelength : Wavelength = 600;
        attribute intensity : LightIntensity;
        attribute decayTime : DecayTime;
    }

    item def RawPhotodetectorSignal {
        attribute intensity : LightIntensity;
        attribute decayTime : DecayTime;
    }

    item def ProcessedMeasurement {
        attribute oxygenConcentration : OxygenConcentration;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute timestamp : TimeStamp;
    }

    item def DigitalDataPacket {
        attribute payload : ProcessedMeasurement;
        attribute protocol : String = "RS-485";
    }

    // ===== Ports =====
    port def BlueLightOut {
        out light : BlueLight;
    }
    port def BlueLightIn {
        in light : BlueLight;
    }
    port def FluorescenceOut {
        out emission : FluorescentEmission;
    }
    port def FluorescenceIn {
        in emission : FluorescentEmission;
    }
    port def PowerOut {
        out voltage : Voltage;
    }
    port def PowerIn {
        in voltage : Voltage;
    }
    port def AnalogSignalOut {
        out signal : RawPhotodetectorSignal;
    }
    port def AnalogSignalIn {
        in signal : RawPhotodetectorSignal;
    }
    port def TempDataOut {
        out temperature : Temperature;
    }
    port def TempDataIn {
        in temperature : Temperature;
    }
    port def PressureDataOut {
        out pressure : Pressure;
    }
    port def PressureDataIn {
        in pressure : Pressure;
    }
    port def DigitalDataOut {
        out packet : DigitalDataPacket;
    }
    port def DigitalDataIn {
        in packet : DigitalDataPacket;
    }

    // ===== Part Definitions =====
    part def PowerSupply {
        port powerOut : PowerOut;
        attribute outputVoltage : Voltage = 5.0;
        attribute maxCurrent : ElectricCurrent = 500.0;
        doc /* Internal power supply providing electrical energy to all optode components. */;
    }

    part def LEDLightSource {
        port powerIn : PowerIn;
        port lightOut : BlueLightOut;
        attribute pulseDuration : DecayTime = 1.0;
        attribute pulseFrequency : Frequency = 1.0;
        attribute wavelength : Wavelength = 470;
        doc /* Blue LED that generates excitation light pulses for the fluorescent dye. */;
    }

    part def DeliveryOpticalFiber {
        port inputEnd : BlueLightIn;
        port outputEnd : BlueLightOut;
        attribute length : Length = 0.5;
        attribute attenuation : Attenuation = 0.1;
        doc /* Optical fiber that guides blue excitation light from the LED to the sensor tip. */;
    }

    part def FluorescentDye {
        attribute excitationWavelength : Wavelength = 470;
        attribute emissionWavelength : Wavelength = 600;
        attribute quantumYield : Real;
        doc /* Chemical indicator dye that fluoresces when excited by blue light and is quenched by dissolved oxygen. */;
    }

    part def SensorTip {
        port excitationIn : BlueLightIn;
        port emissionOut : FluorescenceOut;
        part dye : FluorescentDye;
        attribute isSubmerged : Boolean = false;
        doc /* Sensor tip housing the fluorescent dye, placed directly into the liquid sample. */;
    }

    part def CollectionOpticalFiber {
        port inputEnd : FluorescenceIn;
        port outputEnd : FluorescenceOut;
        attribute length : Length = 0.5;
        attribute attenuation : Attenuation = 0.1;
        doc /* Optical fiber that guides fluorescent emission from the sensor tip to the photodetector. */;
    }

    part def Photodetector {
        port lightIn : FluorescenceIn;
        port signalOut : AnalogSignalOut;
        port powerIn : PowerIn;
        attribute sensitivity : Real = 0.5;
        attribute darkCurrent : ElectricCurrent = 1.0;
        doc /* Photodetector that measures the intensity and decay time of the fluorescent emission. */;
    }

    part def TemperatureSensor {
        port dataOut : TempDataOut;
        port powerIn : PowerIn;
        attribute minRange : Temperature = -5.0;
        attribute maxRange : Temperature = 50.0;
        attribute accuracy : Real = 0.1;
        doc /* Integrated temperature sensor for compensating oxygen concentration readings. */;
    }

    part def PressureSensor {
        port dataOut : PressureDataOut;
        port powerIn : PowerIn;
        attribute minRange : Pressure = 0.0;
        attribute maxRange : Pressure = 10.0;
        attribute accuracy : Real = 0.01;
        doc /* Integrated pressure sensor for compensating oxygen concentration readings. */;
    }

    // ===== Action Definition =====
    action def ProcessMeasurement {
        in rawSignal : RawPhotodetectorSignal;
        in temp : Temperature;
        in pressure : Pressure;
        out result : ProcessedMeasurement;

        attribute tau0 : DecayTime = 60.0;
        attribute Ksv : Real = 0.001;

        action calculateDecayTime {
            in signal : RawPhotodetectorSignal;
            out tau : DecayTime;
            doc /* Extracts fluorescence decay time from the raw photodetector signal. */;
        }
        action applyTemperatureCompensation {
            in tau : DecayTime;
            in temp : Temperature;
            out compensatedTau : DecayTime;
            doc /* Corrects the measured decay time for temperature effects on fluorescence quenching. */;
        }
        action applyPressureCompensation {
            in compensatedTau : DecayTime;
            in pressure : Pressure;
            out finalTau : DecayTime;
            doc /* Corrects the temperature-compensated decay time for pressure effects on oxygen solubility. */;
        }
        action calculateOxygenConcentration {
            in finalTau : DecayTime;
            out concentration : OxygenConcentration;
            doc /* Applies the Stern-Volmer equation to compute dissolved oxygen concentration from the compensated decay time. */;
        }
        action assembleMeasurement {
            in concentration : OxygenConcentration;
            in temp : Temperature;
            in pressure : Pressure;
            out result : ProcessedMeasurement;
            doc /* Assembles the final calibrated measurement packet with concentration, temperature, pressure, and timestamp. */;
        }

        first calculateDecayTime then applyTemperatureCompensation then applyPressureCompensation then calculateOxygenConcentration then assembleMeasurement;

        flow from rawSignal to calculateDecayTime.signal;
        flow from calculateDecayTime.tau to applyTemperatureCompensation.tau;
        flow from temp to applyTemperatureCompensation.temp;
        flow from applyTemperatureCompensation.compensatedTau to applyPressureCompensation.compensatedTau;
        flow from pressure to applyPressureCompensation.pressure;
        flow from applyPressureCompensation.finalTau to calculateOxygenConcentration.finalTau;
        flow from calculateOxygenConcentration.concentration to assembleMeasurement.concentration;
        flow from temp to assembleMeasurement.temp;
        flow from pressure to assembleMeasurement.pressure;
        flow from assembleMeasurement.result to result;
    }

    part def SignalProcessingUnit {
        port signalIn : AnalogSignalIn;
        port tempIn : TempDataIn;
        port pressureIn : PressureDataIn;
        port dataOut : DigitalDataOut;
        port powerIn : PowerIn;
        attribute samplingRate : Frequency = 1000.0;
        attribute calibrationCoefficients : Real[3] = (1.0, 0.0, 0.0);
        action processMeasurement : ProcessMeasurement;
        doc /* Onboard signal processor that calculates calibrated dissolved oxygen concentration from fluorescence decay time, temperature, and pressure. */;
    }

    part def DataInterface {
        port dataIn : DigitalDataIn;
        port dataOut : DigitalDataOut;
        port powerIn : PowerIn;
        attribute protocol : String = "RS-485";
        attribute baudRate : Integer = 9600;
        doc /* Data interface that formats and transmits calibrated oxygen readings to an external monitoring system via RS-485. */;
    }

    // ===== Main Optode Part =====
    part def Optode {
        port externalInterface : DigitalDataOut;

        part powerSupply : PowerSupply;
        part led : LEDLightSource;
        part deliveryFiber : DeliveryOpticalFiber;
        part sensorTip : SensorTip;
        part collectionFiber : CollectionOpticalFiber;
        part photodetector : Photodetector;
        part temperatureSensor : TemperatureSensor;
        part pressureSensor : PressureSensor;
        part processor : SignalProcessingUnit;
        part dataInterface : DataInterface;

        // Power distribution
        connect powerSupply.powerOut to led.powerIn;
        connect powerSupply.powerOut to photodetector.powerIn;
        connect powerSupply.powerOut to temperatureSensor.powerIn;
        connect powerSupply.powerOut to pressureSensor.powerIn;
        connect powerSupply.powerOut to processor.powerIn;
        connect powerSupply.powerOut to dataInterface.powerIn;

        // Optical excitation path
        connect led.lightOut to deliveryFiber.inputEnd;
        connect deliveryFiber.outputEnd to sensorTip.excitationIn;

        // Optical emission path
        connect sensorTip.emissionOut to collectionFiber.inputEnd;
        connect collectionFiber.outputEnd to photodetector.lightIn;

        // Electrical signal path
        connect photodetector.signalOut to processor.signalIn;
        connect temperatureSensor.dataOut to processor.tempIn;
        connect pressureSensor.dataOut to processor.pressureIn;
        connect processor.dataOut to dataInterface.dataIn;
        connect dataInterface.dataOut to externalInterface;

        // State machine for continuous measurement cycle
        state machine MeasurementCycle {
            attribute powerOn : Boolean = true;

            state Idle {
                doc /* System ready, waiting to begin next measurement cycle. */;
            }
            state EmittingBlueLight {
                doc /* LED generates a blue light pulse to excite the fluorescent dye. */;
            }
            state ExcitingDye {
                doc /* Blue light reaches the dye at the sensor tip, causing fluorescence emission. */;
            }
            state CollectingFluorescence {
                doc /* Collection fiber captures the emitted fluorescent light from the dye. */;
            }
            state DetectingSignal {
                doc /* Photodetector measures the intensity and decay time of the fluorescence. */;
            }
            state ProcessingData {
                doc /* Signal processor calculates dissolved oxygen concentration with temperature and pressure compensation. */;
            }
            state TransmittingData {
                doc /* Data interface transmits the calibrated reading including concentration, temperature, pressure, and timestamp via RS-485. */;
            }

            transition initial to Idle;
            transition from Idle to EmittingBlueLight when powerOn;
            transition from EmittingBlueLight to ExcitingDye;
            transition from ExcitingDye to CollectingFluorescence;
            transition from CollectingFluorescence to DetectingSignal;
            transition from DetectingSignal to ProcessingData;
            transition from ProcessingData to TransmittingData;
            transition from TransmittingData to Idle;
        }

        satisfy MeasureDissolvedOxygen;
        satisfy ContinuousMeasurement;
        satisfy MeasurementAccuracy;
    }

    // ===== Requirements =====
    requirement def MeasureDissolvedOxygen {
        subject optode : Optode;
        doc /* The optode shall measure dissolved oxygen concentration in liquid samples using the principle of fluorescence quenching. */;
    }

    requirement def BlueLightExcitation {
        subject led : LEDLightSource;
        attribute wavelength : Wavelength = 470;
        attribute pulseDuration : DecayTime = 1.0;
        doc /* The LED shall emit blue light pulses at the specified wavelength and duration to excite the fluorescent indicator dye. */;
    }

    requirement def FluorescenceQuenchingDetection {
        subject sensorTip : SensorTip;
        doc /* The sensor tip shall detect fluorescence quenching caused by dissolved oxygen in the sample and emit corresponding fluorescent light whose intensity and decay time vary with oxygen concentration. */;
    }

    requirement def FluorescenceCollection {
        subject collectionFiber : CollectionOpticalFiber;
        doc /* The collection optical fiber shall guide fluorescent emission from the sensor tip to the photodetector with minimal signal loss. */;
    }

    requirement def Photodetection {
        subject photodetector : Photodetector;
        doc /* The photodetector shall measure the intensity and decay time of the fluorescent emission and produce a raw signal for the signal processing unit. */;
    }

    requirement def TemperatureCompensation {
        subject processor : SignalProcessingUnit;
        doc /* The signal processor shall compensate the dissolved oxygen measurement for temperature variations using data from the integrated temperature sensor. */;
    }

    requirement def PressureCompensation {
        subject processor : SignalProcessingUnit;
        doc /* The signal processor shall compensate the dissolved oxygen measurement for pressure variations using data from the integrated pressure sensor. */;
    }

    requirement def DataOutputFormat {
        subject dataInterface : DataInterface;
        attribute protocol : String = "RS-485";
        doc /* The data interface shall transmit calibrated oxygen readings including concentration, temperature, pressure, and timestamp to an external monitoring system using the RS-485 communication protocol. */;
    }

    requirement def ContinuousMeasurement {
        subject optode : Optode;
        doc /* The optode shall provide continuous, real-time dissolved oxygen measurements by repeating the measurement cycle indefinitely while powered. */;
    }

    requirement def MeasurementAccuracy {
        subject optode : Optode;
        attribute maxError : OxygenConcentration = 0.1;
        doc /* The optode shall achieve dissolved oxygen measurement accuracy within 0.1 mg/L after temperature and pressure compensation. */;
    }

    requirement def PowerDistribution {
        subject powerSupply : PowerSupply;
        attribute outputVoltage : Voltage = 5.0;
        doc /* The internal power supply shall provide stable electrical power to all optode components including the LED, photodetector, sensors, processor, and data interface. */;
    }

    // ===== Requirement Satisfaction =====
    part ledInstance : LEDLightSource {
        satisfy BlueLightExcitation;
    }

    part tipInstance : SensorTip {
        satisfy FluorescenceQuenchingDetection;
    }

    part collectionFiberInstance : CollectionOpticalFiber {
        satisfy FluorescenceCollection;
    }

    part photodetectorInstance : Photodetector {
        satisfy Photodetection;
    }

    part processorInstance : SignalProcessingUnit {
        satisfy TemperatureCompensation;
        satisfy PressureCompensation;
    }

    part dataInterfaceInstance : DataInterface {
        satisfy DataOutputFormat;
    }

    part powerSupplyInstance : PowerSupply {
        satisfy PowerDistribution;
    }
}
