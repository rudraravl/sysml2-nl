package MechanicalVentilationSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    
    package Definitions {
        item def Air;
        
        value def PressureValue :> Real {
            attribute unit : String = "cmH2O";
        }
        value def VolumeValue :> Real {
            attribute unit : String = "mL";
        }
        value def FlowRateValue :> Real {
            attribute unit : String = "mL/s";
        }
        value def FrequencyValue :> Real {
            attribute unit : String = "breaths/min";
        }
        
        port def AirPort {
            out item inspiredAir : Air;
            in item expiredAir : Air;
        }
        
        part def Cuff {
            attribute pressure : PressureValue;
            attribute isInflated : Boolean = false;
        }
        
        part def Lumen;
        part def BeveledTip;
        part def MurphyEye;
        
        part def Trachea {
            port trachealPort : ~AirPort;
        }
        
        part def Airway {
            part trachea : Trachea;
        }
        
        part def Patient {
            part airway : Airway;
        }
        
        part def TrachealTube {
            attribute length : Real {
                attribute unit : String = "mm";
            }
            part lumen : Lumen;
            part cuff : Cuff;
            part beveledTip : BeveledTip;
            part murphyEye : MurphyEye;
            port proximalPort : ~AirPort;
            port distalPort : AirPort;
        }
        
        part def Ventilator {
            port patientPort : AirPort;
            attribute tidalVolume : VolumeValue;
            attribute respiratoryRate : FrequencyValue;
            attribute oxygenConcentration : Real;
        }
        
        connection def TubeToTrachea {
            end tube : TrachealTube;
            end trachea : Trachea;
            flow of air : Air from tube.distalPort.inspiredAir to trachea.trachealPort.inspiredAir;
            flow of air : Air from trachea.trachealPort.expiredAir to tube.distalPort.expiredAir;
        }
        
        connection def VentilatorToTube {
            end ventilator : Ventilator;
            end tube : TrachealTube;
            flow of air : Air from ventilator.patientPort.inspiredAir to tube.proximalPort.inspiredAir;
            flow of air : Air from tube.proximalPort.expiredAir to ventilator.patientPort.expiredAir;
        }
        
        action def VentilationProcedure {
            in ref trachealTube : TrachealTube;
            in ref patientRef : Patient;
            in ref ventilatorRef : Ventilator;
            action prepareTube;
            then action insertTube;
            then action inflateCuff {
                attribute targetPressure : PressureValue = 25.0;
            }
            then action connectVentilator;
            then action ventilatePatient;
            then action monitorVentilation;
            then action deflateCuff;
            then action removeTube;
        }
        
        requirement def SafeCuffPressureRequirement {
            text "Cuff pressure must be maintained between 20 and 30 cmH2O to ensure seal without mucosal injury.";
        }
        
        requirement def AdequateVentilationRequirement {
            text "Tidal volume shall be at least 400 mL, respiratory rate at least 8 breaths/min, and oxygen concentration at least 0.21.";
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part ventilationSystem {
            part patient : Patient;
            part tube : TrachealTube;
            part ventilator : Ventilator;
            
            connection tubeToTrachea : TubeToTrachea connect tube to patient.airway.trachea;
            connection ventilatorToTube : VentilatorToTube connect ventilator to tube;
            
            perform action procedure : VentilationProcedure {
                in ref trachealTube = tube;
                in ref patientRef = patient;
                in ref ventilatorRef = ventilator;
            }
        }
        
        satisfy SafeCuffPressureRequirement by ventilationSystem.tube.cuff;
        satisfy AdequateVentilationRequirement by ventilationSystem.ventilator;
    }
}
