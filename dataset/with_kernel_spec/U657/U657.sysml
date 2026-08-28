package 'Electro-Optical Sensing Unit' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def Wavelength :> Real;
    attribute def Irradiance :> Real;
    attribute def Photocurrent :> Real;
    attribute def AnalogVoltage :> Real;
    attribute def ConfidenceScore :> Real;

    item def Light;
    item def FilteredLight;
    item def RawDigitalData;
    item def Measurement {
        attribute irradiance : Irradiance;
        attribute confidence : ConfidenceScore;
        attribute timestamp : DateTime;
    }

    attribute def PowerUpSignal;
    attribute def InitCompleteSignal;
    attribute def TriggerSignal;
    attribute def AcquireComplete;
    attribute def ProcessComplete;
    attribute def ValidateComplete;
    attribute def OutputCompleteSignal;
    attribute def PowerOffSignal;

    part def OpticalWindow {
        attribute ipRating : String = "IP67";
        attribute coatingType : String = "Anti-Reflective";
        in light : Light;
        out filteredLight : FilteredLight;
    }

    part def Photodetector {
        attribute spectralRangeMin : Wavelength = 400;
        attribute spectralRangeMax : Wavelength = 1100;
        in filteredLight : FilteredLight;
        out current : Photocurrent;
    }

    part def TransimpedanceAmplifier {
        in current : Photocurrent;
        out voltage : AnalogVoltage;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 24;
        in voltage : AnalogVoltage;
        out digitalData : RawDigitalData;
    }

    part def SignalProcessingUnit {
        in digitalData : RawDigitalData;
        out measurement : Measurement;
    }

    part def PowerSupply {
        in powerIn : AnalogVoltage;
        out powerRail : AnalogVoltage;
    }

    action def PerformSelfTest;
    action def PerformCalibration;
    action def AcquireData;
    action def ProcessData;
    action def ValidateData;
    action def OutputData;

    state def SensorLifecycle {
        entry; then off;
        state off;
        accept PowerUpSignal
            then initialization;
        state initialization {
            entry PerformSelfTest;
            do PerformCalibration;
        }
        accept InitCompleteSignal
            then standby;
        state standby;
        accept TriggerSignal
            then measuring;
        state measuring {
            entry; then acquiring;
            state acquiring {
                do AcquireData;
            }
            accept AcquireComplete
                then processing;
            state processing {
                do ProcessData;
            }
            accept ProcessComplete
                then validating;
            state validating {
                do ValidateData;
            }
            accept ValidateComplete
                then outputting;
            state outputting {
                do OutputData;
            }
            accept OutputCompleteSignal
                then standby;
        }
        accept PowerOffSignal
            then off;
    }

    part def ElectroOpticalSensingUnit {
        in incomingLight : Light;
        in powerInput : AnalogVoltage;
        in trigger : TriggerSignal;
        out measurementOut : Measurement;

        part opticalWindow : OpticalWindow {
            in light = ElectroOpticalSensingUnit::incomingLight;
        }
        part photodetector : Photodetector;
        part tia : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;
        part spu : SignalProcessingUnit {
            out measurement :> ElectroOpticalSensingUnit::measurementOut;
        }
        part powerSupply : PowerSupply {
            in powerIn = ElectroOpticalSensingUnit::powerInput;
        }

        flow opticalWindow.filteredLight to photodetector.filteredLight;
        flow photodetector.current to tia.current;
        flow tia.voltage to adc.voltage;
        flow adc.digitalData to spu.digitalData;

        exhibit state lifecycle : SensorLifecycle;
    }

    part sensingUnit : ElectroOpticalSensingUnit;

    requirement 'Measure Optical Irradiance' {
        doc /* The Electro-Optical Sensing Unit shall measure the intensity of incoming light (optical irradiance) and convert it into a calibrated and validated digital measurement. */
    }

    requirement 'Optical Window Specification' {
        doc /* The optical window shall be environmentally sealed with an IP67 rating and coated to reduce reflections. */
    }

    requirement 'Photodetector Spectrum' {
        doc /* The photodetector shall be sensitive to a wide spectrum of light from 400nm to 1100nm. */
    }

    requirement 'High Resolution ADC' {
        doc /* The analog-to-digital converter shall provide a minimum resolution of 24 bits. */
    }

    requirement 'Operational Lifecycle' {
        doc /* The unit shall initialize with self-test and calibration upon power-up, wait in standby, and upon trigger, sequentially acquire, process, validate, and output data before returning to standby. */
    }
}
