package 'Tristimulus Colorimeter' {
    import ScalarValues::*;

    attribute def CurrentValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def DigitalValue :> Real;
    attribute def CCTValue :> Real;
    attribute def LuminousIntensity :> Real;

    item def Light {
        attribute intensity : LuminousIntensity;
    }
    item def DiffuseLight :> Light;
    item def FilteredLight :> Light;

    attribute def XYZ {
        attribute X : Real;
        attribute Y : Real;
        attribute Z : Real;
    }
    attribute def Chromaticity {
        attribute x : Real;
        attribute y : Real;
    }
    item def ColorMeasurement {
        attribute tristimulus : XYZ;
        attribute chromaticity : Chromaticity;
        attribute cct : CCTValue;
    }

    attribute def FilterPosition :> String;

    port def LightInPort { in light : Light; }
    port def DiffuseLightPort { out diffuseLight : DiffuseLight; }
    port def FilteredLightPort { out filteredLight : FilteredLight; }
    port def CurrentPort { out current : CurrentValue; }
    port def VoltagePort { out voltage : VoltageValue; }
    port def DigitalPort { out digitalValue : DigitalValue; }
    port def MeasurementPort { out measurement : ColorMeasurement; }
    port def ControlPort { out position : FilterPosition; }

    action def DiffuseLightAction { in item light : Light; out item diffuseLight : DiffuseLight; }
    action def FilterLightAction { in item diffuseLight : DiffuseLight; out item filteredLight : FilteredLight; }
    action def SenseLightAction { in item filteredLight : FilteredLight; out current : CurrentValue; }
    action def AmplifyAction { in current : CurrentValue; out voltage : VoltageValue; }
    action def DigitizeAction { in voltage : VoltageValue; out digitalValue : DigitalValue; }
    action def ComputeMeasurementAction {
        in xDigital : DigitalValue;
        in yDigital : DigitalValue;
        in zDigital : DigitalValue;
        out item measurement : ColorMeasurement;
    }
    action def DisplayAction { in item measurement : ColorMeasurement; }
    action def TransmitAction { in item measurement : ColorMeasurement; out item measurementOut : ColorMeasurement; }
    action def MeasureColor;

    part def IntegratingSphere {
        port lightIn : LightInPort;
        port diffuseOut : DiffuseLightPort;
    }

    part def FilterWheel {
        port diffuseIn : ~DiffuseLightPort;
        port filteredOut : FilteredLightPort;
        port controlIn : ~ControlPort;
        attribute position : FilterPosition;
    }

    part def PhotodiodeSensor {
        port filteredIn : ~FilteredLightPort;
        port currentOut : CurrentPort;
    }

    part def TransimpedanceAmplifier {
        port currentIn : ~CurrentPort;
        port voltageOut : VoltagePort;
    }

    part def ADC {
        port voltageIn : ~VoltagePort;
        port digitalOut : DigitalPort;
    }

    part def MeasurementChannel {
        part sensor : PhotodiodeSensor;
        part amplifier : TransimpedanceAmplifier;
        part adc : ADC;
        port filteredIn : ~FilteredLightPort;
        port digitalOut : DigitalPort;
        connect filteredIn to sensor.filteredIn;
        connect sensor.currentOut to amplifier.currentIn;
        connect amplifier.voltageOut to adc.voltageIn;
        connect adc.digitalOut to digitalOut;
    }

    part def Microprocessor {
        port xIn : ~DigitalPort;
        port yIn : ~DigitalPort;
        port zIn : ~DigitalPort;
        port controlOut : ControlPort;
        port measurementOut : MeasurementPort;
        attribute calibration : Real;
    }

    part def DisplayModule {
        port measurementIn : ~MeasurementPort;
    }

    part def DataPort {
        port measurementIn : ~MeasurementPort;
        port measurementOut : MeasurementPort;
    }

    part def TristimulusColorimeter {
        port lightEntry : LightInPort;
        port dataOutput : MeasurementPort;
        part sphere : IntegratingSphere;
        part filterWheel : FilterWheel;
        part xChannel : MeasurementChannel;
        part yChannel : MeasurementChannel;
        part zChannel : MeasurementChannel;
        part processor : Microprocessor;
        part display : DisplayModule;
        part dataPort : DataPort;
        connect lightEntry to sphere.lightIn;
        connect sphere.diffuseOut to filterWheel.diffuseIn;
        connect filterWheel.filteredOut to xChannel.filteredIn;
        connect filterWheel.filteredOut to yChannel.filteredIn;
        connect filterWheel.filteredOut to zChannel.filteredIn;
        connect xChannel.digitalOut to processor.xIn;
        connect yChannel.digitalOut to processor.yIn;
        connect zChannel.digitalOut to processor.zIn;
        connect processor.controlOut to filterWheel.controlIn;
        connect processor.measurementOut to display.measurementIn;
        connect processor.measurementOut to dataPort.measurementIn;
        connect dataPort.measurementOut to dataOutput;
    }

    action measureColor : MeasureColor {
        first start;
        then action trigger { out item light : Light; }
        flow from trigger.light to diffuseStep.light;
        then action diffuseStep : DiffuseLightAction { in item light; out item diffuseLight; }
        flow from diffuseStep.diffuseLight to filterXStep.diffuseLight;
        then action filterXStep : FilterLightAction { in item diffuseLight; out item filteredLight; }
        flow from filterXStep.filteredLight to senseX.filteredLight;
        then action senseX : SenseLightAction { in item filteredLight; out current; }
        flow from senseX.current to amplifyX.current;
        then action amplifyX : AmplifyAction { in current; out voltage; }
        flow from amplifyX.voltage to digitizeX.voltage;
        then action digitizeX : DigitizeAction { in voltage; out digitalValue; }
        flow from diffuseStep.diffuseLight to filterYStep.diffuseLight;
        then action filterYStep : FilterLightAction { in item diffuseLight; out item filteredLight; }
        flow from filterYStep.filteredLight to senseY.filteredLight;
        then action senseY : SenseLightAction { in item filteredLight; out current; }
        flow from senseY.current to amplifyY.current;
        then action amplifyY : AmplifyAction { in current; out voltage; }
        flow from amplifyY.voltage to digitizeY.voltage;
        then action digitizeY : DigitizeAction { in voltage; out digitalValue; }
        flow from diffuseStep.diffuseLight to filterZStep.diffuseLight;
        then action filterZStep : FilterLightAction { in item diffuseLight; out item filteredLight; }
        flow from filterZStep.filteredLight to senseZ.filteredLight;
        then action senseZ : SenseLightAction { in item filteredLight; out current; }
        flow from senseZ.current to amplifyZ.current;
        then action amplifyZ : AmplifyAction { in current; out voltage; }
        flow from amplifyZ.voltage to digitizeZ.voltage;
        then action digitizeZ : DigitizeAction { in voltage; out digitalValue; }
        flow from digitizeX.digitalValue to computeStep.xDigital;
        flow from digitizeY.digitalValue to computeStep.yDigital;
        flow from digitizeZ.digitalValue to computeStep.zDigital;
        then action computeStep : ComputeMeasurementAction { in xDigital; in yDigital; in zDigital; out item measurement; }
        flow from computeStep.measurement to displayStep.measurement;
        then action displayStep : DisplayAction { in item measurement; }
        flow from computeStep.measurement to transmitStep.measurement;
        then action transmitStep : TransmitAction { in item measurement; out item measurementOut; }
    }

    requirement def ColorMeasurementRequirement {
        doc /* The colorimeter shall measure CIE tristimulus values (XYZ), chromaticity coordinates (xy), and correlated color temperature (CCT). */
    }

    requirement colorMeasurementReq : ColorMeasurementRequirement;

    part colorimeter : TristimulusColorimeter {
        perform measureColor;
    }

    satisfy colorMeasurementReq by colorimeter;
}
