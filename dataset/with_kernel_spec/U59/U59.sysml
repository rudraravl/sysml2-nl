package 'Environmental Accelerated Testing' {
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def TestProfile {
        attribute targetTemp : TemperatureValue;
        attribute targetHumidity : Real;
        attribute duration : TimeValue;
    }
    
    attribute def TempFeedback {
        attribute temp : TemperatureValue;
    }
    
    attribute def HumidityFeedback {
        attribute humidity : Real;
    }
    
    attribute def EmergencyShutdownSignal;
    attribute def LoadCommand;
    attribute def UnloadCommand;
    attribute def LoadCompleteSignal;
    attribute def UnloadCompleteSignal;
    attribute def TestProfileProgrammed;
    
    part def TestSpecimen;
    
    part def EnvironmentalChamber {
        port heaterControlPort { in power : PowerValue; }
        port coolerControlPort { in power : PowerValue; }
        port humidifierControlPort { in power : PowerValue; }
        
        part heater {
            port controlPort { in power : PowerValue; }
        }
        part cooler {
            port controlPort { in power : PowerValue; }
        }
        part humidifier {
            port controlPort { in power : PowerValue; }
        }
        
        flow heaterFlow of PowerValue from heaterControlPort to heater.controlPort;
        flow coolerFlow of PowerValue from coolerControlPort to cooler.controlPort;
        flow humidifierFlow of PowerValue from humidifierControlPort to humidifier.controlPort;
    }
    
    part def SpecimenLoadingSystem {
        port loadCmdPort { in cmd : LoadCommand; }
        port loadStatusPort { out status : LoadCompleteSignal; }
        port unloadCmdPort { in cmd : UnloadCommand; }
        port unloadStatusPort { out status : UnloadCompleteSignal; }
    }
    
    part def TemperatureSensor {
        port feedbackPort { out temp : TempFeedback; }
    }
    
    part def HumiditySensor {
        port feedbackPort { out humidity : HumidityFeedback; }
    }
    
    part def ControlSystem {
        port tempFeedbackPort { in temp : TempFeedback; }
        port humidityFeedbackPort { in humidity : HumidityFeedback; }
        port heaterCmdPort { out power : PowerValue; }
        port coolerCmdPort { out power : PowerValue; }
        port humidifierCmdPort { out power : PowerValue; }
        port profilePort { in profile : TestProfile; }
        port safetyPort { in sig : EmergencyShutdownSignal; }
        port loaderCmdPort { out cmd : LoadCommand; }
        port loaderStatusPort { in status : LoadCompleteSignal; }
        port unloaderCmdPort { out cmd : UnloadCommand; }
        port unloaderStatusPort { in status : UnloadCompleteSignal; }
        
        action controlEnvironment {
            in targetTemp : TemperatureValue;
            in targetHumidity : Real;
            in actualTemp : TemperatureValue;
            in actualHumidity : Real;
            out heaterPower : PowerValue;
            out coolerPower : PowerValue;
            out humidifierPower : PowerValue;
        }
        
        action cutPower {
            out heaterPower : PowerValue := 0 [W];
            out coolerPower : PowerValue := 0 [W];
            out humidifierPower : PowerValue := 0 [W];
        }
        
        state def ControlStates;
        state controlStates : ControlStates {
            entry; then idle;
            state idle;
            accept TestProfileProgrammed
                then loading;
            state loading {
                entry send new LoadCommand() via loaderCmdPort;
                accept LoadCompleteSignal
                    then preheating;
            }
            state preheating {
                do controlEnvironment {
                    in targetTemp = profilePort.profile.targetTemp;
                    in targetHumidity = profilePort.profile.targetHumidity;
                    in actualTemp = tempFeedbackPort.temp.temp;
                    in actualHumidity = humidityFeedbackPort.humidity.humidity;
                    out heaterPower = heaterCmdPort.power;
                    out coolerPower = coolerCmdPort.power;
                    out humidifierPower = humidifierCmdPort.power;
                }
                accept when tempFeedbackPort.temp.temp >= profilePort.profile.targetTemp
                    then stabilizing;
            }
            state stabilizing {
                do controlEnvironment {
                    in targetTemp = profilePort.profile.targetTemp;
                    in targetHumidity = profilePort.profile.targetHumidity;
                    in actualTemp = tempFeedbackPort.temp.temp;
                    in actualHumidity = humidityFeedbackPort.humidity.humidity;
                    out heaterPower = heaterCmdPort.power;
                    out coolerPower = coolerCmdPort.power;
                    out humidifierPower = humidifierCmdPort.power;
                }
                accept when tempFeedbackPort.temp.temp == profilePort.profile.targetTemp
                    and humidityFeedbackPort.humidity.humidity == profilePort.profile.targetHumidity
                    then activeTesting;
            }
            state activeTesting {
                do controlEnvironment {
                    in targetTemp = profilePort.profile.targetTemp;
                    in targetHumidity = profilePort.profile.targetHumidity;
                    in actualTemp = tempFeedbackPort.temp.temp;
                    in actualHumidity = humidityFeedbackPort.humidity.humidity;
                    out heaterPower = heaterCmdPort.power;
                    out coolerPower = coolerCmdPort.power;
                    out humidifierPower = humidifierCmdPort.power;
                }
                accept after profilePort.profile.duration
                    then cooldown;
            }
            state cooldown {
                do controlEnvironment {
                    in targetTemp = 30 [degC];
                    in targetHumidity = 0.0;
                    in actualTemp = tempFeedbackPort.temp.temp;
                    in actualHumidity = humidityFeedbackPort.humidity.humidity;
                    out heaterPower = heaterCmdPort.power;
                    out coolerPower = coolerCmdPort.power;
                    out humidifierPower = humidifierCmdPort.power;
                }
                accept when tempFeedbackPort.temp.temp <= 30 [degC]
                    then unloading;
            }
            state unloading {
                entry send new UnloadCommand() via unloaderCmdPort;
                accept UnloadCompleteSignal
                    then idle;
            }
            accept EmergencyShutdownSignal
                then emergency;
            state emergency {
                entry cutPower {
                    out heaterPower = heaterCmdPort.power;
                    out coolerPower = coolerCmdPort.power;
                    out humidifierPower = humidifierCmdPort.power;
                }
            }
        }
    }
    
    part def DataAcquisitionSystem {
        port tempDataPort { in temp : TempFeedback; }
        port humidityDataPort { in humidity : HumidityFeedback; }
    }
    
    part def SafetySystem {
        port tempFeedbackPort { in temp : TempFeedback; }
        port shutdownPort { out sig : EmergencyShutdownSignal; }
        
        attribute maxSafeTemp : TemperatureValue := 150 [degC];
        
        state def SafetyStates;
        state safetyStates : SafetyStates {
            entry; then monitoring;
            state monitoring;
            accept when tempFeedbackPort.temp.temp > maxSafeTemp
                then shutdown;
            state shutdown {
                entry send new EmergencyShutdownSignal() via shutdownPort;
            }
        }
    }
    
    part def EATSystem {
        part chamber : EnvironmentalChamber;
        part loadingSystem : SpecimenLoadingSystem;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part controller : ControlSystem;
        part dataAcq : DataAcquisitionSystem;
        part safetySystem : SafetySystem;
        
        interface tempSensorToController connect tempSensor.feedbackPort to controller.tempFeedbackPort;
        interface humiditySensorToController connect humiditySensor.feedbackPort to controller.humidityFeedbackPort;
        interface controllerToHeater connect controller.heaterCmdPort to chamber.heaterControlPort;
        interface controllerToCooler connect controller.coolerCmdPort to chamber.coolerControlPort;
        interface controllerToHumidifier connect controller.humidifierCmdPort to chamber.humidifierControlPort;
        interface tempSensorToDataAcq connect tempSensor.feedbackPort to dataAcq.tempDataPort;
        interface humiditySensorToDataAcq connect humiditySensor.feedbackPort to dataAcq.humidityDataPort;
        interface tempSensorToSafety connect tempSensor.feedbackPort to safetySystem.tempFeedbackPort;
        interface safetyToController connect safetySystem.shutdownPort to controller.safetyPort;
        interface controllerToLoader connect controller.loaderCmdPort to loadingSystem.loadCmdPort;
        interface loaderToController connect loadingSystem.loadStatusPort to controller.loaderStatusPort;
        interface controllerToUnloader connect controller.unloaderCmdPort to loadingSystem.unloadCmdPort;
        interface unloaderToController connect loadingSystem.unloadStatusPort to controller.unloaderStatusPort;
    }
    
    requirement def ReliabilityRequirement {
        subject specimen : TestSpecimen;
        objective {
            doc "The system shall subject the specimen to the specified environmental profile to test reliability.";
        }
    }
    
    requirement def SafetyRequirement {
        subject system : EATSystem;
        objective {
            doc "The system shall trigger an emergency shutdown if chamber temperature exceeds safe limits.";
        }
    }
}
