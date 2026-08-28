package 'Image Sensing Unit' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def Scene;
        item def Light;
        item def AnalogSignal;
        item def RawImageFrame;
        item def ProcessedImageFrame;

        item def Command {
            attribute exposure : ExposureTime;
            attribute gain : GainValue;
        }

        item def StatusReport {
            attribute operationalState : String;
            attribute temperature : TemperatureValue;
            attribute errors : String;
        }

        attribute def IlluminanceValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def ExposureTime :> Real;
        attribute def GainValue :> Real;

        attribute def 'Power On';
        attribute def 'Power Off';
        attribute def 'Capture';
        attribute def 'Capture Done';
        attribute def 'Process Done';
        attribute def 'Transmit Done';

        port def CommandPort { in item command : Command; }
        port def StatusPort { out item status : StatusReport; }
        port def RawDataPort { out item rawFrame : RawImageFrame; }
        port def ImagePort { out item image : ProcessedImageFrame; }
        port def ScenePort { in item scene : Scene; }

        action def FocusLight { in item scene : Scene; out item light : Light; }
        action def GenerateAnalogSignal { in item light : Light; in exposureTime : ExposureTime; in gain : GainValue; out item analogSignal : AnalogSignal; }
        action def SenseIlluminance { in item scene : Scene; out illuminance : IlluminanceValue; }
        action def CalculateExposure { in illuminance : IlluminanceValue; in commandExposure : ExposureTime; in commandGain : GainValue; out exposureTime : ExposureTime; out gain : GainValue; }
        action def ConvertAnalogToDigital { in item analogSignal : AnalogSignal; out item rawFrame : RawImageFrame; }
        action def ProcessImage { in item rawFrame : RawImageFrame; out item image : ProcessedImageFrame; }
        action def StoreData { in item rawFrame : RawImageFrame; in item image : ProcessedImageFrame; }
        action def RegulateTemperature { in temp : TemperatureValue; out coolingActive : Boolean; }
        action def ManagePower { out powerEnabled : Boolean; }
        action def ReportStatus { out item status : StatusReport; }

        part def LensAssembly {
            in item scene : Scene;
            out item light : Light;
            perform action focus : FocusLight {
                in item scene = scene;
                out item light = light;
            }
        }

        part def PhotodetectorArray {
            in item light : Light;
            in exposureTime : ExposureTime;
            in gain : GainValue;
            out item analogSignal : AnalogSignal;
            out temp : TemperatureValue;
            perform action generate : GenerateAnalogSignal {
                in item light = light;
                in exposureTime = exposureTime;
                in gain = gain;
                out item analogSignal = analogSignal;
            }
        }

        part def IlluminanceMeter {
            in item scene : Scene;
            out illuminance : IlluminanceValue;
            perform action measure : SenseIlluminance {
                in item scene = scene;
                out illuminance = illuminance;
            }
        }

        part def ExposureControlUnit {
            in illuminance : IlluminanceValue;
            in commandExposure : ExposureTime;
            in commandGain : GainValue;
            out exposureTime : ExposureTime;
            out gain : GainValue;
            perform action calculate : CalculateExposure {
                in illuminance = illuminance;
                in commandExposure = commandExposure;
                in commandGain = commandGain;
                out exposureTime = exposureTime;
                out gain = gain;
            }
        }

        part def AnalogToDigitalConverter {
            in item analogSignal : AnalogSignal;
            out item rawFrame : RawImageFrame;
            perform action convert : ConvertAnalogToDigital {
                in item analogSignal = analogSignal;
                out item rawFrame = rawFrame;
            }
        }

        part def ImageSignalProcessor {
            in item rawFrame : RawImageFrame;
            out item image : ProcessedImageFrame;
            perform action process : ProcessImage {
                in item rawFrame = rawFrame;
                out item image = image;
            }
        }

        part def PowerManagement {
            out powerEnabled : Boolean;
            perform action manage : ManagePower {
                out powerEnabled = powerEnabled;
            }
        }

        part def ThermalRegulation {
            in temp : TemperatureValue;
            out coolingActive : Boolean;
            attribute maxTemp : TemperatureValue = 85.0;
            perform action regulate : RegulateTemperature {
                in temp = temp;
                out coolingActive = coolingActive;
            }
        }

        part def DataStorage {
            in item rawFrame : RawImageFrame;
            in item image : ProcessedImageFrame;
            perform action store : StoreData {
                in item rawFrame = rawFrame;
                in item image = image;
            }
        }

        part def ImageSensorModule {
            in item scene : Scene;
            in command : Command;
            out item rawFrame : RawImageFrame;
            out item image : ProcessedImageFrame;
            out temp : TemperatureValue;

            part lens : LensAssembly {
                in item scene = ImageSensorModule::scene;
                out item light;
            }
            flow from lens.light to photodetectorArray.light;

            part illuminanceMeter : IlluminanceMeter {
                in item scene = ImageSensorModule::scene;
                out illuminance;
            }
            flow from illuminanceMeter.illuminance to exposureControl.illuminance;

            part exposureControl : ExposureControlUnit {
                in commandExposure = command.exposure;
                in commandGain = command.gain;
                out exposureTime;
                out gain;
            }
            flow from exposureControl.exposureTime to photodetectorArray.exposureTime;
            flow from exposureControl.gain to photodetectorArray.gain;

            part photodetectorArray : PhotodetectorArray {
                in item light;
                in exposureTime;
                in gain;
                out item analogSignal;
                out temp :> ImageSensorModule::temp;
            }
            flow from photodetectorArray.analogSignal to adc.analogSignal;

            part adc : AnalogToDigitalConverter {
                in item analogSignal;
                out item rawFrame :> ImageSensorModule::rawFrame;
            }
            flow from adc.rawFrame to isp.rawFrame;

            part isp : ImageSignalProcessor {
                in item rawFrame;
                out item image :> ImageSensorModule::image;
            }
        }

        state def 'Sensing Unit States';

        part def ImageSensingUnit {
            port cmdIn : CommandPort;
            port statusOut : StatusPort;
            port rawOut : RawDataPort;
            port imgOut : ImagePort;
            port sceneIn : ScenePort;

            exhibit state 'sensing unit states': 'Sensing Unit States';

            part powerManagement : PowerManagement;
            part thermalRegulation : ThermalRegulation {
                in temp = imageSensorModule.temp;
            }
            part dataStorage : DataStorage {
                in item rawFrame = imageSensorModule.rawFrame;
                in item image = imageSensorModule.image;
            }
            part imageSensorModule : ImageSensorModule {
                in item scene = sceneIn.scene;
                in command = cmdIn.command;
                out item rawFrame :> rawOut.rawFrame;
                out item image :> imgOut.image;
                out temp;
            }

            flow from imageSensorModule.temp to thermalRegulation.temp;
            flow from imageSensorModule.rawFrame to dataStorage.rawFrame;
            flow from imageSensorModule.image to dataStorage.image;
        }

        requirement def 'REQ-001' {
            doc "The Image Sensing Unit shall automatically calculate optimal exposure time based on measured scene illuminance.";
        }
        requirement def 'REQ-002' {
            doc "The unit shall transition to a standby state upon power-on and await capture commands.";
        }
        requirement def 'REQ-003' {
            doc "The thermal regulation system shall activate active cooling when temperature exceeds 85 degrees Celsius.";
        }
    }

    package Usages {
        private import Definitions::*;

        part sensingUnit : ImageSensingUnit {
            port cmdIn;
            port statusOut;
            port rawOut;
            port imgOut;
            port sceneIn;
        }

        part externalController {
            port cmdOut : CommandPort;
            port statusIn : StatusPort;
        }

        connect externalController.cmdOut to sensingUnit.cmdIn;
        connect sensingUnit.statusOut to externalController.statusIn;

        state 'sensing unit states': 'Sensing Unit States' parallel {
            state 'operational states' {
                entry; then 'power-off';
                state 'power-off';
                accept 'Power On' then standby;
                state standby;
                accept 'Capture' then capturing;
                state capturing;
                accept 'Capture Done' then processing;
                state processing;
                accept 'Process Done' then transmitting;
                state transmitting;
                accept 'Transmit Done' then standby;
                accept 'Power Off' then 'power-off';
            }
            state 'thermal states' {
                entry; then normal;
                state normal;
                accept when sensingUnit.imageSensorModule.temp > sensingUnit.thermalRegulation.maxTemp then overheated;
                state overheated {
                    entry action reportStatus {
                        send new StatusReport() via sensingUnit.statusOut;
                    }
                }
                accept when sensingUnit.imageSensorModule.temp <= sensingUnit.thermalRegulation.maxTemp then normal;
            }
        }

        requirement req1 : 'REQ-001';
        requirement req2 : 'REQ-002';
        requirement req3 : 'REQ-003';

        satisfy req1 by sensingUnit.imageSensorModule.exposureControl;
        satisfy req2 by sensingUnit.powerManagement;
        satisfy req3 by sensingUnit.thermalRegulation;
    }
}
