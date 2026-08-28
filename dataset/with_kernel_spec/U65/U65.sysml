package GastricBalloonSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def VolumeValue :> ISQ::volume;
        attribute def PressureValue :> ISQ::pressure;
        attribute def TemperatureValue :> ISQ::temperature;
        
        item def SalineSolution;
        item def SensorData {
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
            attribute temperature : TemperatureValue;
        }
        item def ControlCommand;
        attribute def SafetyAlert;
        
        attribute def DeploySignal;
        attribute def InflateComplete;
        attribute def DeflateSignal;
        attribute def DeflateComplete;
        attribute def RemoveSignal;
        
        port def FluidPort {
            out item saline : SalineSolution;
            in item returnSaline : SalineSolution;
        }
        port def DataPort {
            in item data : SensorData;
            out item command : ControlCommand;
        }
        port def AlertPort {
            out item alert : SafetyAlert;
        }
        
        part def IntragastricBalloon {
            attribute maxVolume : VolumeValue = 700 [mL];
            attribute minVolume : VolumeValue = 400 [mL];
            attribute maxPressure : PressureValue = 20 [mmHg];
            attribute maxTemperature : TemperatureValue = 37 [degC];
            
            port fluidPort : FluidPort;
            port dataPort : ~DataPort;
            
            exhibit state balloonStates : BalloonStates;
            perform action deploy : DeployBalloon;
            perform action inflate : InflateBalloon;
            perform action monitor : MonitorBalloon;
            perform action deflate : DeflateBalloon;
            perform action remove : RemoveBalloon;
        }
        
        part def CatheterSystem {
            port proximalFluidPort : FluidPort;
            port distalFluidPort : ~FluidPort;
        }
        
        part def InflationPump {
            port fluidPort : ~FluidPort;
            port controlPort : ~DataPort;
        }
        
        part def DeflationPump {
            port fluidPort : FluidPort;
            port controlPort : ~DataPort;
        }
        
        part def MonitoringUnit {
            port dataPort : DataPort;
            port alertPort : AlertPort;
            perform action monitorData : MonitorData;
        }
        
        part def ControlUnit {
            port inflationControlPort : DataPort;
            port deflationControlPort : DataPort;
            port alertPort : ~AlertPort;
            attribute treatmentDuration : Real = 180;
            perform action manageTreatment : ManageTreatment;
        }
        
        part def Patient {
            part stomach;
        }
        
        action def DeployBalloon;
        action def InflateBalloon {
            in item saline : SalineSolution;
        }
        action def MonitorBalloon {
            out item data : SensorData;
        }
        action def DeflateBalloon {
            out item saline : SalineSolution;
        }
        action def RemoveBalloon;
        action def MonitorData {
            in item data : SensorData;
            out item alert : SafetyAlert;
        }
        action def ManageTreatment;
        
        state def BalloonStates;
        
        requirement def WeightLossRequirement {
            doc /* The patient should lose 10-15% of body weight over 6 months. */
            attribute targetWeightLossMin : Real = 0.10;
            attribute targetWeightLossMax : Real = 0.15;
            attribute duration : Real = 180;
            subject patient : Patient;
        }
        
        requirement def VolumeRequirement {
            doc /* The balloon must be filled to a volume between 400 and 700 mL. */
            attribute minVolume : VolumeValue = 400 [mL];
            attribute maxVolume : VolumeValue = 700 [mL];
            subject balloon : IntragastricBalloon;
        }
        
        requirement def SafetyRequirement {
            doc /* The system must trigger safety alerts if readings exceed safe thresholds. */
            subject monitoringUnit : MonitoringUnit;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action deploy : DeployBalloon;
        action inflate : InflateBalloon;
        action monitor : MonitorBalloon;
        action deflate : DeflateBalloon;
        action remove : RemoveBalloon;
        action monitorData : MonitorData;
        action manageTreatment : ManageTreatment;
        
        part gastricBalloonSystem {
            part balloon : IntragastricBalloon;
            part catheter : CatheterSystem;
            part inflationPump : InflationPump;
            part deflationPump : DeflationPump;
            part monitoringUnit : MonitoringUnit;
            part controlUnit : ControlUnit;
            part patient : Patient;
            
            connect balloon.fluidPort to catheter.distalFluidPort;
            connect catheter.proximalFluidPort to inflationPump.fluidPort;
            connect catheter.proximalFluidPort to deflationPump.fluidPort;
            
            connect balloon.dataPort to monitoringUnit.dataPort;
            connect monitoringUnit.alertPort to controlUnit.alertPort;
            
            connect controlUnit.inflationControlPort to inflationPump.controlPort;
            connect controlUnit.deflationControlPort to deflationPump.controlPort;
            
            state balloonStates : BalloonStates {
                entry; then deflated;
                state deflated;
                accept DeploySignal then inflating;
                state inflating {
                    do inflate;
                    accept InflateComplete then inflated;
                }
                state inflated {
                    do monitor;
                    accept DeflateSignal then deflating;
                    accept SafetyAlert then deflating;
                }
                state deflating {
                    do deflate;
                    accept DeflateComplete then deflated;
                }
                accept RemoveSignal then removed;
                state removed;
            }
        }
        
        requirement weightLoss : WeightLossRequirement {
            subject patient = gastricBalloonSystem.patient;
        }
        
        requirement volumeReq : VolumeRequirement {
            subject balloon = gastricBalloonSystem.balloon;
        }
        
        requirement safetyReq : SafetyRequirement {
            subject monitoringUnit = gastricBalloonSystem.monitoringUnit;
        }
    }
}
