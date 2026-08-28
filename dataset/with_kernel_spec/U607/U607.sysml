package 'Scientific Irradiance Instrument' {
    private import ScalarValues::*;

    item def Light;
    item def Charge;
    item def RawDigitalData;
    item def CorrectedData;

    attribute def ExposureTime :> Real;
    attribute def TemperatureValue :> Real;
    attribute def IrradianceValue :> Real;
    attribute def ElectricPower :> Real;

    attribute def StartExposure;
    attribute def ExposureComplete;
    attribute def ReadoutComplete;
    attribute def ProcessingComplete;
    attribute def Reset;

    part def BackIlluminatedSensor {
        attribute quantumEfficiency : Real = 0.90;
        attribute operatingTemp : TemperatureValue = 258;
        in light : Light;
        out charge : Charge;
        part microlensArray;
        part antiReflectiveCoating;
        part photodiodeArray;
    }

    part def ThermalController {
        in tempReading : TemperatureValue;
        out coolingPower : ElectricPower;
        part thermoelectricCooler;
        part temperatureSensor;
    }

    part def ReadoutCircuitry {
        in charge : Charge;
        out data : RawDigitalData;
        part amplifier;
        part noiseFilter;
        part adc;
    }

    part def SignalProcessingUnit {
        in data : RawDigitalData;
        out irradiance : IrradianceValue;
        action def CorrectImage;
        action def CalculateIrradiance;
    }

    part def PowerRegulator {
        in externalPower : ElectricPower;
        out regulatedPower : ElectricPower;
    }

    part def ControlInterface {
        in exposureSetting : ExposureTime;
        out status : String;
    }

    action def CaptureLight {
        in light : Light;
        out charge : Charge;
    }
    action def Readout {
        in charge : Charge;
        out data : RawDigitalData;
    }
    action def ProcessData {
        in data : RawDigitalData;
        out corrected : CorrectedData;
    }
    action def ComputeIrradiance {
        in corrected : CorrectedData;
        out irradiance : IrradianceValue;
    }

    state def InstrumentStates;

    requirement def Req_ThermalStability {
        text = "The sensor operating temperature shall be maintained at 258 K ± 0.5 K to minimize dark current.";
    }
    requirement def Req_HighQuantumEfficiency {
        text = "The back-illuminated sensor shall achieve >90% quantum efficiency across 400-1000 nm wavelengths.";
    }
    requirement def Req_MeasurementSequence {
        text = "The instrument shall follow the idle -> exposing -> readout -> processing -> complete state sequence.";
    }
    requirement def Req_DataAccuracy {
        text = "The final irradiance calculation shall apply dark frame and flat-field corrections with <1% residual error.";
    }

    part def Instrument {
        port powerIn { in externalPower : ElectricPower; }
        port lightIn { in light : Light; }
        port dataOut { out irradiance : IrradianceValue; }
        port controlPort { in exposureSetting : ExposureTime; out status : String; }

        part powerRegulator : PowerRegulator {
            in externalPower = powerIn.externalPower;
            out regulatedPower;
        }
        part controlInterface : ControlInterface {
            in exposureSetting = controlPort.exposureSetting;
            out status = controlPort.status;
        }
        part sensor : BackIlluminatedSensor {
            in light = lightIn.light;
            out charge;
        }
        part thermalController : ThermalController {
            in tempReading = sensor.operatingTemp;
            out coolingPower;
        }
        part readoutCircuitry : ReadoutCircuitry {
            in charge = sensor.charge;
            out data;
        }
        part signalProcessor : SignalProcessingUnit {
            in data = readoutCircuitry.data;
            out irradiance = dataOut.irradiance;
        }

        perform action measureIrradiance {
            in light = lightIn.light;
            out irradiance = dataOut.irradiance;

            action capture : CaptureLight {
                in light = light;
                out charge = sensor.charge;
            }
            action readout : Readout {
                in charge = capture.charge;
                out data = readoutCircuitry.data;
            }
            action process : ProcessData {
                in data = readout.data;
                out corrected;
            }
            action compute : ComputeIrradiance {
                in corrected = process.corrected;
                out irradiance = irradiance;
            }
        }

        exhibit state instrumentStates : InstrumentStates {
            entry; then idle;
            state idle;
            accept StartExposure
                then exposing;
            state exposing {
                do measureIrradiance.capture;
            }
            accept ExposureComplete
                then readout;
            state readout {
                do measureIrradiance.readout;
            }
            accept ReadoutComplete
                then processing;
            state processing {
                entry measureIrradiance.process;
                do measureIrradiance.compute;
            }
            accept ProcessingComplete
                then complete;
            state complete;
            accept Reset
                then idle;
        }

        satisfy Req_ThermalStability;
        satisfy Req_HighQuantumEfficiency;
        satisfy Req_MeasurementSequence;
        satisfy Req_DataAccuracy;
    }
}
