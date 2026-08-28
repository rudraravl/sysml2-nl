package AirPurificationSystem {
    import ScalarValues::*;

    item def Air;
    item def ContaminatedAir :> Air {
        attribute pmConcentration : Real;
        attribute vocConcentration : Real;
        attribute odorLevel : Real;
    }
    item def PurifiedAir :> Air {
        attribute pmConcentration : Real;
        attribute vocConcentration : Real;
        attribute odorLevel : Real;
    }

    attribute def AirQualityIndex : Real;
    attribute def FanSpeed : Real;
    attribute def FilterLifePercentage : Real;
    attribute def Power : Real;

    port def AirPort {
        item air : Air;
    }
    port def PowerPort {
        attribute power : Power;
    }
    port def DataPort {
        attribute data : Real;
    }
    port def CommandPort {
        attribute command : String;
    }

    requirement def PurifyAir {
        doc "The system shall remove airborne contaminants from indoor air."
    }
    requirement def AdjustFanSpeed {
        doc "The control unit shall adjust fan speed based on air quality."
    }
    requirement def AlertFilterMaintenance {
        doc "The system shall alert the user when HEPA filter life drops below 10%."
    }

    part def AirPurifier {
        satisfy PurifyAir;
        
        in port powerIn : PowerPort;
        in port intake : AirPort;
        out port exhaust : AirPort;
        
        part powerSupply : PowerSupply {
            in port powerIn : PowerPort;
            out port powerOut : PowerPort;
        }
        
        part sensor : AirQualitySensor {
            in port powerIn : PowerPort;
            in port airSample : AirPort;
            out port aqiOut : DataPort;
        }
        
        part controlUnit : ControlUnit {
            in port powerIn : PowerPort;
            in port aqiIn : DataPort;
            in port commandIn : CommandPort;
            out port fanSpeedOut : DataPort;
            out port displayOut : DataPort;
            out port alertOut : DataPort;
            satisfy AdjustFanSpeed;
        }
        
        part fan : Fan {
            in port powerIn : PowerPort;
            in port speedIn : DataPort;
            in port airIn : AirPort;
            out port airOut : AirPort;
        }
        
        part preFilter : PreFilter {
            in port airIn : AirPort;
            out port airOut : AirPort;
        }
        
        part hepaFilter : HEPAFilter {
            in port airIn : AirPort;
            out port airOut : AirPort;
            attribute remainingLife : FilterLifePercentage = 100;
        }
        
        part carbonFilter : ActivatedCarbonFilter {
            in port airIn : AirPort;
            out port airOut : AirPort;
        }
        
        part userInterface : UserInterface {
            in port powerIn : PowerPort;
            out port commandOut : CommandPort;
            in port displayIn : DataPort;
            in port alertIn : DataPort;
            satisfy AlertFilterMaintenance;
        }
        
        connection powerConn1 connect powerIn to powerSupply.powerIn;
        connection powerConn2 connect powerSupply.powerOut to controlUnit.powerIn;
        connection powerConn3 connect powerSupply.powerOut to fan.powerIn;
        connection powerConn4 connect powerSupply.powerOut to sensor.powerIn;
        connection powerConn5 connect powerSupply.powerOut to userInterface.powerIn;
        
        connection airConn1 connect intake to sensor.airSample;
        connection airConn2 connect intake to preFilter.airIn;
        connection airConn3 connect preFilter.airOut to hepaFilter.airIn;
        connection airConn4 connect hepaFilter.airOut to carbonFilter.airIn;
        connection airConn5 connect carbonFilter.airOut to fan.airIn;
        connection airConn6 connect fan.airOut to exhaust;
        
        connection dataConn1 connect sensor.aqiOut to controlUnit.aqiIn;
        connection dataConn2 connect controlUnit.fanSpeedOut to fan.speedIn;
        connection dataConn3 connect controlUnit.displayOut to userInterface.displayIn;
        connection dataConn4 connect controlUnit.alertOut to userInterface.alertIn;
        connection dataConn5 connect userInterface.commandOut to controlUnit.commandIn;
    }

    part def PowerSupply {
        in port powerIn : PowerPort;
        out port powerOut : PowerPort;
    }
    
    part def AirQualitySensor {
        in port powerIn : PowerPort;
        in port airSample : AirPort;
        out port aqiOut : DataPort;
        attribute currentAQI : AirQualityIndex;
    }
    
    part def ControlUnit {
        in port powerIn : PowerPort;
        in port aqiIn : DataPort;
        in port commandIn : CommandPort;
        out port fanSpeedOut : DataPort;
        out port displayOut : DataPort;
        out port alertOut : DataPort;
        
        attribute hepaFilterLife : FilterLifePercentage = 100;
        
        exhibit state ControlState {
            state Off {
                entry action { 
                    fanSpeedOut.data = 0; 
                    displayOut.data = 0;
                }
            }
            state Standby {
                entry action { 
                    fanSpeedOut.data = 20; 
                    displayOut.data = aqiIn.data;
                }
            }
            state AutoMode {
                entry action { 
                    if aqiIn.data > 150 { 
                        fanSpeedOut.data = 100; 
                    } else if aqiIn.data > 50 { 
                        fanSpeedOut.data = 50; 
                    } else { 
                        fanSpeedOut.data = 20; 
                    }
                    displayOut.data = aqiIn.data;
                }
                do action { 
                    hepaFilterLife = hepaFilterLife - 0.01; 
                }
            }
            state FilterMaintenance {
                entry action { 
                    fanSpeedOut.data = 0; 
                    alertOut.data = 1; 
                    displayOut.data = hepaFilterLife;
                }
            }
            
            transition first Off if commandIn.command == "PowerOn" then Standby;
            transition Standby if commandIn.command == "PowerOff" then Off;
            transition Standby if commandIn.command == "Auto" then AutoMode;
            transition AutoMode if commandIn.command == "Standby" then Standby;
            transition AutoMode if hepaFilterLife < 10 then FilterMaintenance;
            transition FilterMaintenance if commandIn.command == "Reset" then Standby;
        }
    }
    
    part def Fan {
        in port powerIn : PowerPort;
        in port speedIn : DataPort;
        in port airIn : AirPort;
        out port airOut : AirPort;
        attribute currentSpeed : FanSpeed;
    }
    
    part def PreFilter {
        in port airIn : AirPort;
        out port airOut : AirPort;
    }
    
    part def HEPAFilter {
        in port airIn : AirPort;
        out port airOut : AirPort;
        attribute remainingLife : FilterLifePercentage;
    }
    
    part def ActivatedCarbonFilter {
        in port airIn : AirPort;
        out port airOut : AirPort;
    }
    
    part def UserInterface {
        in port powerIn : PowerPort;
        out port commandOut : CommandPort;
        in port displayIn : DataPort;
        in port alertIn : DataPort;
    }
}
