package Psychrometer {
    import ScalarValues::*;
    import SI::*;

    value def TemperatureValue :> Real { unit 'degC'; }
    value def PressureValue :> Real { unit 'Pa'; }
    value def HumidityValue :> Real { unit '%'; }
    value def FlowRateValue :> Real { unit 'm3/s'; }
    value def VolumeValue :> Real { unit 'm3'; }
    value def TimeValue :> Real { unit 's'; }

    item def Air;
    item def Water;

    port def AirFlowOutPort {
        out item air : Air;
        out attr flowRate : FlowRateValue;
    }
    port def AirFlowInPort {
        in item air : Air;
        in attr flowRate : FlowRateValue;
    }
    port def WaterSupplyOutPort {
        out item water : Water;
    }
    port def WaterSupplyInPort {
        in item water : Water;
    }
    port def TempDataOutPort {
        out attr temp : TemperatureValue;
    }
    port def TempDataInPort {
        in attr temp : TemperatureValue;
    }
    port def PressureDataOutPort {
        out attr pressure : PressureValue;
    }
    port def PressureDataInPort {
        in attr pressure : PressureValue;
    }
    port def DisplayDataOutPort {
        out attr dryTemp : TemperatureValue;
        out attr wetTemp : TemperatureValue;
        out attr humidity : HumidityValue;
    }
    port def DisplayDataInPort {
        in attr dryTemp : TemperatureValue;
        in attr wetTemp : TemperatureValue;
        in attr humidity : HumidityValue;
    }

    part def DryBulbThermometer {
        port airIn : AirFlowInPort;
        port tempOut : TempDataOutPort;
        attribute measuredTemp : TemperatureValue;
        
        action measureTemp {
            out result : TemperatureValue = measuredTemp;
        }
    }

    part def WetBulbThermometer {
        port airIn : AirFlowInPort;
        port waterIn : WaterSupplyInPort;
        port tempOut : TempDataOutPort;
        attribute measuredTemp : TemperatureValue;
        
        action measureTemp {
            out result : TemperatureValue = measuredTemp;
        }
    }

    part def WaterReservoir {
        port waterOut : WaterSupplyOutPort;
        attribute capacity : VolumeValue = 0.05 [m3];
        attribute currentVolume : VolumeValue = 0.05 [m3];
    }

    part def VentilationFan {
        port airOut : AirFlowOutPort;
        attribute flowRate : FlowRateValue = 0.01 [m3/s];
        
        state def FanStateBehavior {
            state Off;
            state On;
            transition initial Off -> On when true;
        }
    }

    part def PressureSensor {
        port pressureOut : PressureDataOutPort;
        attribute measuredPressure : PressureValue;
    }

    part def HumidityProcessor {
        port dryTempIn : TempDataInPort;
        port wetTempIn : TempDataInPort;
        port pressureIn : PressureDataInPort;
        port displayOut : DisplayDataOutPort;
        
        action def ProcessData {
            in dryT : TemperatureValue;
            in wetT : TemperatureValue;
            in p : PressureValue;
            out rh : HumidityValue;
            
            action validate {
                in dryT;
                in wetT;
            }
            action calculate {
                in dryT;
                in wetT;
                in p;
                out rh;
            }
            succession validate then calculate;
        }
    }

    part def DisplayUnit {
        port displayIn : DisplayDataInPort;
        action updateDisplay;
    }

    requirement def PsychrometerRequirements {
        subject p : PsychrometerSystem;
        
        requirement operatingTempRange {
            constraint { p.dryBulb.measuredTemp >= -20 [degC] and p.dryBulb.measuredTemp <= 50 [degC] }
        }
        
        requirement responseTime {
            constraint { p.responseTime <= 30 [s] }
        }
        
        requirement accuracy {
            constraint { p.humidityAccuracy <= 2 [%] }
        }
    }

    part def PsychrometerSystem {
        attribute responseTime : TimeValue = 30 [s];
        attribute humidityAccuracy : HumidityValue = 2 [%];
        
        part dryBulb : DryBulbThermometer;
        part wetBulb : WetBulbThermometer;
        part reservoir : WaterReservoir;
        part fan : VentilationFan;
        part pressureSensor : PressureSensor;
        part processor : HumidityProcessor;
        part display : DisplayUnit;
        
        connect fan.airOut to dryBulb.airIn;
        connect fan.airOut to wetBulb.airIn;
        connect reservoir.waterOut to wetBulb.waterIn;
        connect dryBulb.tempOut to processor.dryTempIn;
        connect wetBulb.tempOut to processor.wetTempIn;
        connect pressureSensor.pressureOut to processor.pressureIn;
        connect processor.displayOut to display.displayIn;
        
        requirement psychrometerReq : PsychrometerRequirements {
            subject p = this;
        }
    }
}
