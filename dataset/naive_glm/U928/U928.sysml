package TristimulusColorimeter {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQElectromagnetism::*;

    // ---------- Value Types ----------
    value type CurrentValue :> RealValue {
        unit ampere;
    }

    value type VoltageValue :> RealValue {
        unit volt;
    }

    value type DigitalCount :> IntegerValue {
    }

    value type TristimulusValue :> RealValue {
    }

    value type ChromaticityCoordinate :> RealValue {
    }

    value type CorrelatedColorTemperature :> RealValue {
        unit kelvin;
    }

    value type AngularPosition :> RealValue {
        unit degree;
    }

    value type FilterPosition :> IntegerValue {
    }

    value type CalibrationCoefficient :> RealValue {
    }

    item def Light {
        attribute intensity : RealValue;
        attribute wavelength : LengthValue;
    }

    item def DiffuseLight :> Light {
    }

    item def FilteredLight :> Light {
        attribute filterId : String;
    }

    item def ColorMeasurement {
        attribute X : TristimulusValue;
        attribute Y : TristimulusValue;
        attribute Z : TristimulusValue;
        attribute x : ChromaticityCoordinate;
        attribute y : ChromaticityCoordinate;
        attribute cct : CorrelatedColorTemperature;
    }

    // ---------- Port Definitions ----------
    port def OpticalPort {
        out light : Light;
    }

    port def DiffuseLightPort {
        out diffuseLight : DiffuseLight;
    }

    port def FilteredLightPort {
        out filteredLight : FilteredLight;
    }

    port def CurrentPort {
        out current : CurrentValue;
    }

    port def VoltagePort {
        out voltage : VoltageValue;
    }

    port def DigitalPort {
        out count : DigitalCount;
    }

    port def MeasurementPort {
        out measurement : ColorMeasurement;
    }

    port def CommandPort {
        in command : String;
    }

    port def ControlPort {
        out command : String;
        in status : String;
    }

    // ---------- Requirements ----------
    requirement def MeasureColorRequirement {
        doc /* The colorimeter shall measure color and provide XYZ, xy, and CCT. */
        subject colorimeter : TristimulusColorimeter;
        objective {
            colorimeter.measurement.X >= 0 and
            colorimeter.measurement.Y >= 0 and
            colorimeter.measurement.Z >= 0 and
            colorimeter.measurement.cct > 0
        }
    }

    requirement def UniformDiffusionRequirement {
        doc /* The integrating sphere shall produce uniformly diffuse light. */
        subject sphere : IntegratingSphere;
        objective {
            sphere.diffuseLight.intensity >= 0
        }
    }

    requirement def SequentialFilterRequirement {
        doc /* The filter wheel shall sequentially present X, Y, and Z filters. */
        subject wheel : FilterWheel;
        objective {
            wheel.sequenceCompleted == true
        }
    }

    requirement def ThreeChannelRequirement {
        doc /* The system shall use three identical measurement channels. */
        subject channels : MeasurementChannel[3];
        objective {
            channels->size() == 3
        }
    }

    requirement def CalibrationRequirement {
        doc /* The processor shall use a calibration matrix to compute XYZ. */
        subject processor : Microprocessor;
        objective {
            processor.calibrationMatrix->size() == 9
        }
    }

    // ---------- Parts ----------
    part def OpticalInputPort {
        port opticalOut : OpticalPort;
        attribute apertureDiameter : LengthValue = 12 [mm];
    }

    part def IntegratingSphere {
        port lightIn : OpticalPort;
        port diffuseOut : DiffuseLightPort;
        attribute innerDiameter : LengthValue = 100 [mm];
        attribute reflectance : RealValue = 0.98;
        attribute diffuseLight : DiffuseLight;
    }

    part def OpticalFilter {
        attribute filterId : String;
        attribute peakWavelength : LengthValue;
        attribute bandwidth : LengthValue;
        attribute transmittance : RealValue;
    }

    part def FilterWheel {
        port lightIn : DiffuseLightPort;
        port filteredOut : FilteredLightPort;
        port control : ControlPort;
        attribute filters : OpticalFilter[3] = (
            OpticalFilter{filterId="X"; peakWavelength=600 [nm]; bandwidth=80 [nm]; transmittance=0.85;},
            OpticalFilter{filterId="Y"; peakWavelength=555 [nm]; bandwidth=60 [nm]; transmittance=0.90;},
            OpticalFilter{filterId="Z"; peakWavelength=450 [nm]; bandwidth=70 [nm]; transmittance=0.82;}
        );
        attribute currentPosition : FilterPosition = 0;
        attribute targetPosition : FilterPosition;
        attribute sequenceCompleted : Boolean = false;
        attribute stepAngle : AngularPosition = 120 [deg];

        action def RotateTo {
            in position : FilterPosition;
            out done : Boolean;
        }

        action def RunSequence {
            out completed : Boolean;
        }
    }

    part def SiliconPhotodiode {
        port lightIn : FilteredLightPort;
        port currentOut : CurrentPort;
        attribute responsivity : RealValue = 0.5; // A/W
        attribute darkCurrent : CurrentValue = 1e-9 [A];
        attribute activeArea : AreaValue = 7.8 [mm^2];
    }

    part def TransimpedanceAmplifier {
        port currentIn : CurrentPort;
        port voltageOut : VoltagePort;
        attribute feedbackResistance : ResistanceValue = 1000000 [ohm];
        attribute gain : RealValue = 1000000;
    }

    part def AnalogToDigitalConverter {
        port voltageIn : VoltagePort;
        port digitalOut : DigitalPort;
        attribute resolutionBits : IntegerValue = 16;
        attribute sampleRate : RealValue = 1000; // samples per second
        attribute fullScaleVoltage : VoltageValue = 5 [V];
    }

    part def MeasurementChannel {
        port lightIn : FilteredLightPort;
        port digitalOut : DigitalPort;
        attribute channelId : String;
        part photodiode : SiliconPhotodiode;
        part amplifier : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;

        connection photodiode.currentOut to amplifier.currentIn;
        connection amplifier.voltageOut to adc.voltageIn;
    }

    part def Microprocessor {
        port digitalInX : DigitalPort;
        port digitalInY : DigitalPort;
        port digitalInZ : DigitalPort;
        port wheelControl : ControlPort;
        port displayOut : MeasurementPort;
        port dataPortOut : MeasurementPort;
        port userCommand : CommandPort;

        attribute calibrationMatrix : CalibrationCoefficient[9] = (
            1.02, 0.01, 0.00,
            0.00, 0.98, 0.01,
            0.01, 0.00, 1.03
        );
        attribute rawX : DigitalCount;
        attribute rawY : DigitalCount;
        attribute rawZ : DigitalCount;
        attribute measurement : ColorMeasurement;

        action def ComputeXYZ {
            in rawX : DigitalCount;
            in rawY : DigitalCount;
            in rawZ : DigitalCount;
            in matrix : CalibrationCoefficient[9];
            out X : TristimulusValue;
            out Y : TristimulusValue;
            out Z : TristimulusValue;
        }

        action def ComputeChromaticity {
            in X : TristimulusValue;
            in Y : TristimulusValue;
            in Z : TristimulusValue;
            out x : ChromaticityCoordinate;
            out y : ChromaticityCoordinate;
        }

        action def ComputeCCT {
            in x : ChromaticityCoordinate;
            in y : ChromaticityCoordinate;
            out cct : CorrelatedColorTemperature;
        }

        action def PerformMeasurement {
            out result : ColorMeasurement;
        }

        state def OperatingState;
        state operating : OperatingState {
            entry; then Idle;
            state Idle;
            transition idle_to_rotating
                first Idle
                if userCommand.command == "MEASURE"
                then RotatingX;
            state RotatingX;
            transition rotatingX_to_sampling
                first RotatingX
                if wheelControl.status == "X_IN_POSITION"
                then SamplingX;
            state SamplingX;
            transition samplingX_to_rotatingY
                first SamplingX
                if digitalInX.count > 0
                then RotatingY;
            state RotatingY;
            transition rotatingY_to_sampling
                first RotatingY
                if wheelControl.status == "Y_IN_POSITION"
                then SamplingY;
            state SamplingY;
            transition samplingY_to_rotatingZ
                first SamplingY
                if digitalInY.count > 0
                then RotatingZ;
            state RotatingZ;
            transition rotatingZ_to_sampling
                first RotatingZ
                if wheelControl.status == "Z_IN_POSITION"
                then SamplingZ;
            state SamplingZ;
            transition samplingZ_to_computing
                first SamplingZ
                if digitalInZ.count > 0
                then Computing;
            state Computing;
            transition computing_to_displaying
                first Computing
                if measurement.cct > 0
                then Displaying;
            state Displaying;
            transition displaying_to_idle
                first Displaying
                if true
                then Idle;
        }
    }

    part def DisplayModule {
        port measurementIn : MeasurementPort;
        attribute displayType : String = "LCD";
        attribute resolution : String = "800x480";
        attribute currentMeasurement : ColorMeasurement;
    }

    part def DataOutputPort {
        port measurementIn : MeasurementPort;
        attribute protocol : String = "RS-232";
        attribute baudRate : IntegerValue = 9600;
    }

    part def TristimulusColorimeter {
        port userCommand : CommandPort;
        port externalData : MeasurementPort;
        attribute measurement : ColorMeasurement;

        part opticalInput : OpticalInputPort;
        part sphere : IntegratingSphere;
        part filterWheel : FilterWheel;
        part channelX : MeasurementChannel { channelId = "X"; }
        part channelY : MeasurementChannel { channelId = "Y"; }
        part channelZ : MeasurementChannel { channelId = "Z"; }
        part processor : Microprocessor;
        part display : DisplayModule;
        part dataPort : DataOutputPort;

        // Optical path
        connection opticalInput.opticalOut to sphere.lightIn;
        connection sphere.diffuseOut to filterWheel.lightIn;
        connection filterWheel.filteredOut to channelX.lightIn;
        connection filterWheel.filteredOut to channelY.lightIn;
        connection filterWheel.filteredOut to channelZ.lightIn;

        // Digital data path
        connection channelX.digitalOut to processor.digitalInX;
        connection channelY.digitalOut to processor.digitalInY;
        connection channelZ.digitalOut to processor.digitalInZ;

        // Control path
        connection processor.wheelControl to filterWheel.control;

        // Output path
        connection processor.displayOut to display.measurementIn;
        connection processor.dataPortOut to dataPort.measurementIn;

        // User command
        connection userCommand to processor.userCommand;

        // External data
        connection processor.dataPortOut to externalData;

        // Requirements satisfaction
        satisfy MeasureColorRequirement by tristimulusColorimeter;
        satisfy UniformDiffusionRequirement by sphere;
        satisfy SequentialFilterRequirement by filterWheel;
        satisfy ThreeChannelRequirement by (channelX, channelY, channelZ);
        satisfy CalibrationRequirement by processor;
    }

}
