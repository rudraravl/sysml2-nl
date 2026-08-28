package LabOnChipDevice {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def BiologicalSample {
            attribute sampleType : String;
        }
        item def Reagent {
            attribute reagentType : String;
        }
        item def DetectionAntibody :> Reagent;
        item def SubstrateSolution :> Reagent;
        item def Mixture;
        item def ReactedFluid;
        item def WasteFluid;

        enum def BiomarkerName {
            enum glucose;
            enum cholesterol;
            enum protein;
        }

        attribute def ConcentrationValue :> Real {
            unit = 'mg/dL';
        }
        attribute def OpticalIntensityValue :> Real {
            unit = 'cd/m2';
        }
        attribute def VolumeValue :> Real {
            unit = 'uL';
        }
        attribute def TemperatureSetpointValue :> Real {
            unit = 'degC';
        }
        attribute def DurationValue :> Real {
            unit = 'min';
        }

        attribute def TestResult {
            attribute biomarker : BiomarkerName;
            attribute concentration : ConcentrationValue;
            attribute status : TestStatusValue;
        }

        enum def TestStatusValue {
            enum idle;
            enum pumping;
            enum mixing;
            enum incubating;
            enum detecting;
            enum complete;
            enum error;
        }

        attribute def StartTestCommand {
            attribute targetBiomarker : BiomarkerName;
        }
        attribute def TestCompleteSignal;
        attribute def TestErrorSignal {
            attribute errorCode : String;
        }

        port def FluidPort {
            out item fluid;
        }
        port def FluidInPort {
            in item fluid;
        }
        port def OpticalSignalPort {
            out signal : OpticalIntensityValue;
        }
        port def CommandPort {
            in command;
        }
        port def ResultPort {
            out result : TestResult;
        }

        action def PumpFluid {
            in item sourceFluid;
            out item pumpedFluid;
            attribute volume : VolumeValue;
        }
        action def MixFluids {
            in item fluidA;
            in item fluidB;
            out item mixture : Mixture;
        }
        action def Incubate {
            in item mixture : Mixture;
            out item reactedFluid : ReactedFluid;
            attribute setpoint : TemperatureSetpointValue;
            attribute duration : DurationValue;
        }
        action def DetectOptical {
            in item fluid : ReactedFluid;
            out signal : OpticalIntensityValue;
        }
        action def AnalyzeSignal {
            in signal : OpticalIntensityValue;
            attribute targetBiomarker : BiomarkerName;
            out concentration : ConcentrationValue;
        }
        action def DisposeWaste {
            in item fluid;
            out item waste : WasteFluid;
        }

        action def RunDiagnosticTest {
            in item sample : BiologicalSample;
            in item reagent1 : DetectionAntibody;
            in item reagent2 : SubstrateSolution;
            attribute targetBiomarker : BiomarkerName;
            out result : TestResult;

            action pumpSample : PumpFluid {
                in sourceFluid;
                out pumpedFluid;
                attribute volume : VolumeValue = 5.0;
            }
            action pumpReagent1 : PumpFluid {
                in sourceFluid;
                out pumpedFluid;
                attribute volume : VolumeValue = 2.0;
            }
            action pumpReagent2 : PumpFluid {
                in sourceFluid;
                out pumpedFluid;
                attribute volume : VolumeValue = 3.0;
            }

            bind pumpSample.sourceFluid = sample;
            bind pumpReagent1.sourceFluid = reagent1;
            bind pumpReagent2.sourceFluid = reagent2;

            first pumpSample then pumpReagent1;
            first pumpReagent1 then pumpReagent2;
            first pumpReagent2 then mix;

            action mix : MixFluids {
                in fluidA = pumpSample.pumpedFluid;
                in fluidB = pumpReagent1.pumpedFluid;
                out mixture;
            }

            flow from mix.mixture to incubate.mixture;

            action incubate : Incubate {
                in mixture;
                out reactedFluid;
                attribute setpoint : TemperatureSetpointValue = 37.0;
                attribute duration : DurationValue = 10.0;
            }

            flow from incubate.reactedFluid to detect.fluid;

            action detect : DetectOptical {
                in fluid;
                out signal;
            }

            flow from detect.signal to analyze.signal;

            action analyze : AnalyzeSignal {
                in signal;
                attribute targetBiomarker;
                out concentration;
            }

            bind analyze.targetBiomarker = targetBiomarker;

            flow from incubate.reactedFluid to dispose.fluid;

            action dispose : DisposeWaste {
                in fluid;
                out waste;
            }

            first mix then incubate;
            first incubate then detect;
            first detect then analyze;
            first analyze then dispose;

            bind result.biomarker = targetBiomarker;
            bind result.concentration = analyze.concentration;
            bind result.status = TestStatusValue::complete;
        }

        part def Reservoir {
            port fluidOut : FluidPort;
            attribute capacity : VolumeValue;
        }
        part def SampleReservoir :> Reservoir {
            item sample : BiologicalSample;
        }
        part def ReagentReservoir :> Reservoir {
            item reagent : Reagent;
        }
        part def WasteReservoir {
            port fluidIn : FluidInPort;
            attribute capacity : VolumeValue;
        }
        part def MicrofluidicPump {
            port fluidIn : FluidInPort;
            port fluidOut : FluidPort;
            attribute dispenseVolume : VolumeValue;
            perform action pump : PumpFluid;
        }
        part def MicrofluidicChannel {
            port fluidIn : FluidInPort;
            port fluidOut : FluidPort;
        }
        part def MixingChamber {
            port fluidInA : FluidInPort;
            port fluidInB : FluidInPort;
            port fluidOut : FluidPort;
            perform action mix : MixFluids;
        }
        part def IncubationChamber {
            port fluidIn : FluidInPort;
            port fluidOut : FluidPort;
            attribute setpoint : TemperatureSetpointValue;
            attribute duration : DurationValue;
            perform action incubate : Incubate;
        }
        part def OpticalDetector {
            port fluidIn : FluidInPort;
            port fluidOut : FluidPort;
            port signalOut : OpticalSignalPort;
            attribute wavelength : Real;
            perform action detect : DetectOptical;
        }
        part def Microcontroller {
            port cmdIn : CommandPort;
            port signalIn : OpticalSignalPort;
            port resultOut : ResultPort;
            perform action analyze : AnalyzeSignal;
            exhibit state 'controller states' : ControllerStates;
        }
        part def LabOnChipDevice {
            port cmdIn : CommandPort;
            port resultOut : ResultPort;
            perform action runTest : RunDiagnosticTest;
            exhibit state 'device states' : DeviceStates;
        }

        state def DeviceStates {
            entry; then idle;
            state idle;
            accept StartTestCommand
                then pumping;
            state pumping;
            accept TestCompleteSignal
                then mixing;
            state mixing;
            accept TestCompleteSignal
                then incubating;
            state incubating;
            accept TestCompleteSignal
                then detecting;
            state detecting;
            accept TestCompleteSignal
                then complete;
            state complete;
            accept StartTestCommand
                then idle;
            state error;
            accept TestErrorSignal
                then error;
        }

        state def ControllerStates {
            entry; then idle;
            state idle;
            accept StartTestCommand
                then analyzing;
            state analyzing;
            accept TestCompleteSignal
                then idle;
        }
    }

    package Usages {
        private import Definitions::*;

        part locDevice : LabOnChipDevice {
            part sampleReservoir : SampleReservoir {
                item sample : BiologicalSample {
                    attribute sampleType = "blood";
                }
                attribute capacity : VolumeValue = 50.0;
            }
            part reagentReservoir1 : ReagentReservoir {
                item reagent : DetectionAntibody;
                attribute capacity : VolumeValue = 20.0;
            }
            part reagentReservoir2 : ReagentReservoir {
                item reagent : SubstrateSolution;
                attribute capacity : VolumeValue = 20.0;
            }
            part wasteReservoir : WasteReservoir {
                attribute capacity : VolumeValue = 100.0;
            }
            part pumpSample : MicrofluidicPump {
                attribute dispenseVolume : VolumeValue = 5.0;
            }
            part pumpReagent1 : MicrofluidicPump {
                attribute dispenseVolume : VolumeValue = 2.0;
            }
            part pumpReagent2 : MicrofluidicPump {
                attribute dispenseVolume : VolumeValue = 3.0;
            }
            part channelToMixer1 : MicrofluidicChannel;
            part channelToMixer2 : MicrofluidicChannel;
            part channelToMixer3 : MicrofluidicChannel;
            part mixingChamber : MixingChamber;
            part channelToIncubator : MicrofluidicChannel;
            part incubationChamber : IncubationChamber {
                attribute setpoint : TemperatureSetpointValue = 37.0;
                attribute duration : DurationValue = 10.0;
            }
            part channelToDetector : MicrofluidicChannel;
            part opticalDetector : OpticalDetector {
                attribute wavelength : Real = 450.0;
            }
            part channelToWaste : MicrofluidicChannel;
            part microcontroller : Microcontroller;

            connection sampleReservoir.fluidOut to pumpSample.fluidIn;
            connection reagentReservoir1.fluidOut to pumpReagent1.fluidIn;
            connection reagentReservoir2.fluidOut to pumpReagent2.fluidIn;

            connection pumpSample.fluidOut to channelToMixer1.fluidIn;
            connection pumpReagent1.fluidOut to channelToMixer2.fluidIn;
            connection pumpReagent2.fluidOut to channelToMixer3.fluidIn;

            connection channelToMixer1.fluidOut to mixingChamber.fluidInA;
            connection channelToMixer2.fluidOut to mixingChamber.fluidInB;
            connection channelToMixer3.fluidOut to mixingChamber.fluidInB;

            connection mixingChamber.fluidOut to channelToIncubator.fluidIn;
            connection channelToIncubator.fluidOut to incubationChamber.fluidIn;
            connection incubationChamber.fluidOut to channelToDetector.fluidIn;
            connection channelToDetector.fluidOut to opticalDetector.fluidIn;
            connection opticalDetector.fluidOut to channelToWaste.fluidIn;
            connection channelToWaste.fluidOut to wasteReservoir.fluidIn;

            connection opticalDetector.signalOut to microcontroller.signalIn;
            connection cmdIn to microcontroller.cmdIn;
            connection microcontroller.resultOut to resultOut;

            perform action runTest : RunDiagnosticTest {
                in sample = sampleReservoir.sample;
                in reagent1 = reagentReservoir1.reagent;
                in reagent2 = reagentReservoir2.reagent;
                attribute targetBiomarker = BiomarkerName::glucose;
                out result;
            }

            bind runTest.pumpSample = pumpSample.pump;
            bind runTest.pumpReagent1 = pumpReagent1.pump;
            bind runTest.pumpReagent2 = pumpReagent2.pump;
            bind runTest.mix = mixingChamber.mix;
            bind runTest.incubate = incubationChamber.incubate;
            bind runTest.detect = opticalDetector.detect;
            bind runTest.analyze = microcontroller.analyze;
        }

        requirement def DiagnosticAccuracyRequirement {
            attribute requiredAccuracy : Real = 0.95;
            doc /* The LOC device shall measure biomarker concentration with an accuracy of at least 95% compared to laboratory reference methods. */
        }
        requirement def IncubationTemperatureRequirement {
            attribute requiredSetpoint : TemperatureSetpointValue = 37.0;
            attribute tolerance : TemperatureSetpointValue = 0.5;
            doc /* The incubation chamber shall maintain fluid temperature within +/- 0.5 degC of the setpoint during incubation. */
        }
        requirement def SampleVolumeRequirement {
            attribute maxSampleVolume : VolumeValue = 10.0;
            doc /* The sample pump shall dispense no more than 10 uL of biological sample per test. */
        }

        requirement diagnosticAccuracy : DiagnosticAccuracyRequirement;
        requirement incubationTemp : IncubationTemperatureRequirement;
        requirement sampleVolume : SampleVolumeRequirement;

        satisfy diagnosticAccuracy by locDevice;
        satisfy incubationTemp by locDevice.incubationChamber;
        satisfy sampleVolume by locDevice.pumpSample;
    }
}
