package ElectrochemicalGasSensor {

    // ---- Enumerations ----
    enum def TargetGas {
        CarbonMonoxide;
        Ozone;
        Oxygen;
        SulfurDioxide;
    }

    // ---- Attribute definitions (signals) ----
    attribute def MeasurementRequest;
    attribute def MeasurementComplete;
    attribute def CalibrationCommand;
    attribute def CalibrationComplete;
    attribute def ErrorDetected;
    attribute def ResetCommand;
    attribute def PowerOn;
    attribute def PowerOff;
    attribute def StabilizedSignal;

    // ---- Attribute definitions (structured) ----
    attribute def CalibrationCoefficients {
        attribute slope : ScalarValues::Real;
        attribute intercept : ScalarValues::Real;
        attribute tempCoef : ScalarValues::Real;
    }

    // ---- Item definitions ----
    item def AmbientAir;
    item def GasSample {
        attribute gasType : TargetGas;
        attribute concentration : ScalarValues::Real;
    }
    item def ReferenceGas {
        attribute knownConcentration : ScalarValues::Real;
        attribute gasType : TargetGas;
    }
    item def ElectricPower {
        attribute voltage : ScalarValues::Real;
    }
    item def DataPacket {
        attribute gasType : TargetGas;
        attribute concentration : ScalarValues::Real;
        attribute temperature : ScalarValues::Real;
        attribute valid : ScalarValues::Boolean;
    }

    // ---- Port definitions ----
    port def GasPort {
        in air : AmbientAir;
    }
    port def PowerPort {
        in power : ElectricPower;
    }
    port def DataOutPort {
        out data : DataPacket;
    }
    port def AnalogSignalPort {
        attribute signal : ScalarValues::Real;
    }
    port def VoltageRefPort {
        attribute reference : ScalarValues::Real;
    }
    port def DigitalSignalPort {
        attribute value : ScalarValues::Integer;
    }
    port def TemperaturePort {
        attribute reading : ScalarValues::Real;
    }

    // ---- Part definitions: Electrochemical cell components ----
    part def GasPermeableMembrane {
        port inlet : GasPort;
        port outlet : GasPort;
        attribute permeability : ScalarValues::Real;
    }

    part def WorkingElectrode {
        port gasIn : GasPort;
        port currentOut : AnalogSignalPort;
        attribute surfaceArea : ScalarValues::Real;
        attribute targetGas : TargetGas := TargetGas::CarbonMonoxide;
    }

    part def CounterElectrode {
        port currentReturn : AnalogSignalPort;
    }

    part def ReferenceElectrode {
        port refOut : VoltageRefPort;
        attribute referenceVoltage : ScalarValues::Real;
    }

    part def ElectrolyteSolution {
        attribute volume : ScalarValues::Real;
        attribute pH : ScalarValues::Real;
    }

    part def ElectrochemicalCell {
        port gasInput : GasPort;
        port rawCurrentOut : AnalogSignalPort;
        port refVoltageOut : VoltageRefPort;
        port biasInput : VoltageRefPort;

        part membrane : GasPermeableMembrane;
        part workingElectrode : WorkingElectrode;
        part counterElectrode : CounterElectrode;
        part referenceElectrode : ReferenceElectrode;
        part electrolyte : ElectrolyteSolution;

        connect gasInput to membrane.inlet;
        connect membrane.outlet to workingElectrode.gasIn;
        connect workingElectrode.currentOut to counterElectrode.currentReturn;
        connect workingElectrode.currentOut to rawCurrentOut;
        connect referenceElectrode.refOut to refVoltageOut;
    }

    // ---- Part definitions: Electronics ----
    part def Potentiostat {
        port signalIn : AnalogSignalPort;
        port refIn : VoltageRefPort;
        port signalOut : AnalogSignalPort;
        port biasOut : VoltageRefPort;
        attribute biasVoltage : ScalarValues::Real;
        attribute gain : ScalarValues::Real;

        action amplify;
        action maintainBias;
    }

    part def AnalogToDigitalConverter {
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalSignalPort;
        attribute samplingRate : ScalarValues::Real;
        attribute resolution : ScalarValues::Integer;

        action convert;
    }

    part def TemperatureSensor {
        port tempOut : TemperaturePort;
        attribute accuracy : ScalarValues::Real;

        action readTemperature;
    }

    part def SignalProcessor {
        port digitalIn : DigitalSignalPort;
        port tempIn : TemperaturePort;
        port dataOut : DataOutPort;
        attribute coefficients : CalibrationCoefficients;
        attribute targetGas : TargetGas := TargetGas::CarbonMonoxide;

        action process;
        action calibrate;
    }

    // ---- System-level part definition ----
    part def ElectrochemicalGasSensorUnit {
        port gasIn : GasPort;
        port powerIn : PowerPort;
        port dataOut : DataOutPort;

        attribute targetGas : TargetGas := TargetGas::CarbonMonoxide;
        attribute warmupDuration : ScalarValues::Real := 30;
        attribute measurementRange : ScalarValues::Real := 1000;
        attribute calibrationInterval : ScalarValues::Real := 86400;

        part cell : ElectrochemicalCell;
        part potentiostat : Potentiostat;
        part adc : AnalogToDigitalConverter;
        part tempSensor : TemperatureSensor;
        part processor : SignalProcessor;

        connect gasIn to cell.gasInput;
        connect cell.rawCurrentOut to potentiostat.signalIn;
        connect cell.refVoltageOut to potentiostat.refIn;
        connect potentiostat.biasOut to cell.biasInput;
        connect potentiostat.signalOut to adc.analogIn;
        connect adc.digitalOut to processor.digitalIn;
        connect tempSensor.tempOut to processor.tempIn;
        connect processor.dataOut to dataOut;

        action stabilize;
        action takeReading;
        action performCalibration;
        action reportError;

        state sensorStates {
            entry; then warmingUp;

            state warmingUp {
                do action stabilize;
            }
            transition warmup_to_ready
                first warmingUp
                accept StabilizedSignal
                then ready;

            state ready;
            accept MeasurementRequest then measuring;
            accept CalibrationCommand then calibrating;
            accept ErrorDetected then fault;
            accept PowerOff then off;

            state measuring {
                do action takeReading;
            }
            transition measuring_to_ready
                first measuring
                accept MeasurementComplete
                then ready;

            state calibrating {
                do action performCalibration;
            }
            transition calibrating_to_ready
                first calibrating
                accept CalibrationComplete
                then ready;

            state fault {
                do action reportError;
            }
            transition fault_to_warmup
                first fault
                accept ResetCommand
                then warmingUp;

            state off;
            accept PowerOn then warmingUp;
        }
    }

    // ---- Requirements ----
    requirement GasDetectionRequirement {
        doc /* The sensor shall detect and measure the concentration of a target gas in ambient air. */
    }

    requirement ConcentrationRangeRequirement {
        attribute minRange : ScalarValues::Real := 0;
        attribute maxRange : ScalarValues::Real := 1000;
        doc /* The sensor shall measure gas concentrations within its specified range. */
    }

    requirement TemperatureCompensationRequirement {
        doc /* The sensor shall compensate for temperature fluctuations using stored calibration coefficients. */
    }

    requirement DigitalOutputRequirement {
        doc /* The sensor shall output a digital data stream indicating the gas concentration in ppm. */
    }

    requirement WarmupRequirement {
        attribute warmupTime : ScalarValues::Real := 30;
        doc /* The sensor shall enter a warmup phase upon power-on before becoming ready for measurement. */
    }

    requirement FaultHandlingRequirement {
        doc /* The sensor shall enter a fault state upon detecting an internal error. */
    }

    requirement MultiGasRequirement {
        doc /* The sensor design shall be applicable to carbon monoxide, ozone, oxygen, and sulfur dioxide. */
    }
}
