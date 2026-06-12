package PsychrometerSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Temperature {
        :>> quantityKind = ISQ::thermodynamicTemperature;
        :>> unit = SI::degreeCelsius;
    }

    attribute def RelativeHumidity {
        :>> quantityKind = ISQ::dimensionless;
        :>> unit = SI::percent;
    }

    attribute def AirPressure {
        :>> quantityKind = ISQ::pressure;
        :>> unit = SI::pascal;
    }

    attribute def AirVelocity {
        :>> quantityKind = ISQ::speed;
        :>> unit = SI::metrePerSecond;
    }

    attribute def TimeDuration {
        :>> quantityKind = ISQ::time;
        :>> unit = SI::second;
    }

    attribute def BatteryEnergy {
        :>> quantityKind = ISQ::energy;
        :>> unit = SI::joule;
    }

    item def AmbientAir {
        attribute dryBulbTemperature : Temperature;
        attribute wetBulbTemperature : Temperature;
        attribute pressure : AirPressure;
        attribute velocityPastSensors : AirVelocity;
        attribute relativeHumidity : RelativeHumidity;
    }

    item def Water {
        attribute temperature : Temperature;
    }

    item def HumidityReading {
        attribute dryBulbTemperature : Temperature;
        attribute wetBulbTemperature : Temperature;
        attribute relativeHumidity : RelativeHumidity;
        attribute ambientPressure : AirPressure;
        attribute sampleTime : TimeDuration;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }

    port def AirSamplePort {
        in item airIn : AmbientAir;
        out item airOut : AmbientAir;
    }

    port def WaterSupplyPort {
        in item wickWater : Water;
    }

    port def ReadingOutputPort {
        out item reading : HumidityReading;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    part def Psychrometer {
        attribute measurementInterval : TimeDuration = 5.0 [SI::second];
        attribute requiredAirVelocity : AirVelocity = 2.5 [SI::metrePerSecond];
        attribute humidityAccuracy : RelativeHumidity = 3.0 [SI::percent];
        attribute dryBulbAccuracy : Temperature = 0.2 [SI::degreeCelsius];
        attribute wetBulbAccuracy : Temperature = 0.2 [SI::degreeCelsius];

        port airPort : AirSamplePort;
        port waterPort : WaterSupplyPort;
        port readingPort : ReadingOutputPort;
        port powerPort : PowerInputPort;

        part dryBulbSensor : DryBulbThermometer;
        part wetBulbSensor : WetBulbThermometer;
        part wickAssembly : WetWickAssembly;
        part airflowDevice : AirflowDevice;
        part pressureSensor : BarometricPressureSensor;
        part processor : HumidityComputationUnit;
        part display : ReadingDisplay;
        part powerSubsystem : PowerSubsystem;

        connect airPort.airIn to airflowDevice.airIn;
        connect airflowDevice.conditionedAirOut to dryBulbSensor.sensedAir;
        connect airflowDevice.conditionedAirOut to wetBulbSensor.sensedAir;
        connect airflowDevice.conditionedAirOut to airPort.airOut;
        connect waterPort.wickWater to wickAssembly.waterInput;
        connect wickAssembly.wettedWick to wetBulbSensor.wickInterface;
        connect dryBulbSensor.temperatureOutput to processor.dryBulbInput;
        connect wetBulbSensor.temperatureOutput to processor.wetBulbInput;
        connect pressureSensor.pressureOutput to processor.pressureInput;
        connect processor.readingOutput to display.readingInput;
        connect processor.readingOutput to readingPort.reading;
        connect powerPort.power to powerSubsystem.externalPowerInput;
        connect powerSubsystem.sensorPowerOutput to dryBulbSensor.powerInput;
        connect powerSubsystem.sensorPowerOutput to wetBulbSensor.powerInput;
        connect powerSubsystem.processorPowerOutput to processor.powerInput;
        connect powerSubsystem.displayPowerOutput to display.powerInput;

        perform action measureHumidity;
    }

    part def DryBulbThermometer {
        attribute accuracy : Temperature = 0.2 [SI::degreeCelsius];
        attribute responseTime : TimeDuration = 3.0 [SI::second];

        port sensedAir : AirSamplePort;
        port powerInput : PowerInputPort;
        out attribute measuredDryBulbTemperature : Temperature;

        port temperatureOutput {
            out item dryBulbTemperature : Temperature;
        }
    }

    part def WetBulbThermometer {
        attribute accuracy : Temperature = 0.2 [SI::degreeCelsius];
        attribute responseTime : TimeDuration = 4.0 [SI::second];

        port sensedAir : AirSamplePort;
        port wickInterface {
            in item wickMoisture : Water;
        }
        port powerInput : PowerInputPort;
        out attribute measuredWetBulbTemperature : Temperature;

        port temperatureOutput {
            out item wetBulbTemperature : Temperature;
        }
    }

    part def WetWickAssembly {
        attribute minimumSaturationDuration : TimeDuration = 10.0 [SI::second];

        port waterInput : WaterSupplyPort;
        port wettedWick {
            out item wickMoisture : Water;
        }

        state wettingState {
            entry; then Dry;

            state Dry;
            state Saturating;
            state Ready;
            state Depleted;

            transition first Dry to Saturating
                accept WaterAdded;

            transition Saturating to Ready
                if elapsedTime >= minimumSaturationDuration;

            transition Ready to Depleted
                if wickMoisture.temperature > 60.0 [SI::degreeCelsius];

            transition Depleted to Saturating
                accept WaterAdded;
        }
    }

    part def AirflowDevice {
        attribute nominalVelocity : AirVelocity = 2.5 [SI::metrePerSecond];
        attribute minimumVelocity : AirVelocity = 2.0 [SI::metrePerSecond];

        port airIn {
            in item sampledAir : AmbientAir;
        }

        port conditionedAirOut {
            out item conditionedAir : AmbientAir;
        }

        action drawAirAcrossBulbs {
            in item ambientAir : AmbientAir;
            out item movingAir : AmbientAir;

            first start;
            then accelerateAir;
            then stabilizeFlow;
            then outputAir;

            action accelerateAir;
            action stabilizeFlow;
            action outputAir;
        }
    }

    part def BarometricPressureSensor {
        attribute accuracy : AirPressure = 100.0 [SI::pascal];

        port pressureOutput {
            out item pressure : AirPressure;
        }
    }

    part def HumidityComputationUnit {
        attribute psychrometricConstant : Real = 0.00066;
        attribute computationPeriod : TimeDuration = 1.0 [SI::second];

        port dryBulbInput {
            in item dryBulbTemperature : Temperature;
        }

        port wetBulbInput {
            in item wetBulbTemperature : Temperature;
        }

        port pressureInput {
            in item ambientPressure : AirPressure;
        }

        port powerInput : PowerInputPort;

        port readingOutput {
            out item reading : HumidityReading;
        }

        action computeRelativeHumidity {
            in item dryBulbTemperature : Temperature;
            in item wetBulbTemperature : Temperature;
            in item ambientPressure : AirPressure;
            out item reading : HumidityReading;

            attribute saturationVaporPressureDry : AirPressure;
            attribute saturationVaporPressureWet : AirPressure;
            attribute actualVaporPressure : AirPressure;
            attribute computedRelativeHumidity : RelativeHumidity;

            first validateInputs;
            then computeSaturationAtDryBulb;
            then computeSaturationAtWetBulb;
            then compensateForEvaporativeCooling;
            then calculateHumidityRatio;
            then publishReading;

            action validateInputs;
            action computeSaturationAtDryBulb;
            action computeSaturationAtWetBulb;
            action compensateForEvaporativeCooling;
            action calculateHumidityRatio;
            action publishReading;
        }
    }

    part def ReadingDisplay {
        attribute refreshPeriod : TimeDuration = 1.0 [SI::second];

        port readingInput {
            in item reading : HumidityReading;
        }

        port powerInput : PowerInputPort;

        action showReading {
            in item reading : HumidityReading;
            first receiveReading;
            then formatValues;
            then updateDisplay;

            action receiveReading;
            action formatValues;
            action updateDisplay;
        }
    }

    part def PowerSubsystem {
        attribute storedEnergy : BatteryEnergy = 18000.0 [SI::joule];

        port externalPowerInput : PowerInputPort;

        port sensorPowerOutput {
            out item sensorPower : ElectricalPower;
        }

        port processorPowerOutput {
            out item processorPower : ElectricalPower;
        }

        port displayPowerOutput {
            out item displayPower : ElectricalPower;
        }

        state powerState {
            entry; then Off;

            state Off;
            state Initializing;
            state SupplyingPower;
            state LowEnergy;
            state Shutdown;

            transition Off to Initializing
                accept PowerApplied;

            transition Initializing to SupplyingPower
                if storedEnergy > 1000.0 [SI::joule];

            transition SupplyingPower to LowEnergy
                if storedEnergy <= 1000.0 [SI::joule];

            transition LowEnergy to Shutdown
                if storedEnergy <= 100.0 [SI::joule];

            transition Shutdown to Off
                accept PowerRemoved;
        }
    }

    action def MeasureHumidity {
        in item ambientAir : AmbientAir;
        in item wickWater : Water;
        out item humidityReading : HumidityReading;

        first prepareWetBulb;
        then drawAirSample;
        then senseDryBulbTemperature;
        then senseWetBulbTemperature;
        then senseAmbientPressure;
        then computeHumidity;
        then outputHumidityReading;

        action prepareWetBulb;
        action drawAirSample;
        action senseDryBulbTemperature;
        action senseWetBulbTemperature;
        action senseAmbientPressure;
        action computeHumidity;
        action outputHumidityReading;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The psychrometer shall determine ambient relative humidity by measuring dry-bulb temperature and wet-bulb temperature of a ventilated air sample, compensating for atmospheric pressure, and reporting a humidity reading to the user. */

        subject psychrometer : Psychrometer;

        require constraint {
            psychrometer.readingPort.reading.relativeHumidity >= 0.0 [SI::percent] and
            psychrometer.readingPort.reading.relativeHumidity <= 100.0 [SI::percent]
        }
    }

    requirement def AirflowRequirement {
        doc /* The psychrometer shall maintain sufficient airflow across both thermometer bulbs during measurement to support evaporative cooling at the wet bulb. */

        subject psychrometer : Psychrometer;

        require constraint {
            psychrometer.airflowDevice.nominalVelocity >= psychrometer.airflowDevice.minimumVelocity
        }
    }

    requirement def WetBulbRequirement {
        doc /* The wet-bulb thermometer shall remain coupled to a saturated wick during active humidity measurement. */

        subject psychrometer : Psychrometer;

        require constraint {
            psychrometer.wickAssembly.minimumSaturationDuration >= 10.0 [SI::second]
        }
    }

    requirement def AccuracyRequirement {
        doc /* The psychrometer shall report relative humidity within the specified accuracy under nominal operating conditions. */

        subject psychrometer : Psychrometer;

        require constraint {
            psychrometer.humidityAccuracy <= 3.0 [SI::percent]
        }
    }

    requirement def MeasurementIntervalRequirement {
        doc /* The psychrometer shall produce a complete humidity reading within the specified measurement interval after airflow and wick saturation are established. */

        subject psychrometer : Psychrometer;

        require constraint {
            psychrometer.measurementInterval <= 5.0 [SI::second]
        }
    }

    part psychrometerSystem : Psychrometer {
        :>> measurementInterval = 5.0 [SI::second];
        :>> requiredAirVelocity = 2.5 [SI::metrePerSecond];
        :>> humidityAccuracy = 3.0 [SI::percent];

        satisfy PrimaryFunctionRequirement by psychrometerSystem;
        satisfy AirflowRequirement by psychrometerSystem;
        satisfy WetBulbRequirement by psychrometerSystem;
        satisfy AccuracyRequirement by psychrometerSystem;
        satisfy MeasurementIntervalRequirement by psychrometerSystem;
    }

}