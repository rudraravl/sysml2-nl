package TrachealTubeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TubeDiameter :> LengthValue;
    attribute def CuffPressure :> PressureValue;
    attribute def AirFlowRate :> VolumetricFlowRateValue;
    attribute def OxygenConcentration :> Real;
    attribute def TidalVolume :> VolumeValue;
    attribute def RespiratoryRate :> FrequencyValue;
    
    enum def TubeStatus {
        stored;
        prepared;
        inserted;
        cuffInflated;
        ventilating;
        deflated;
        removed;
    }
    
    port def AirwayPort {
        attribute pressure : PressureValue;
        attribute flowRate : AirFlowRate;
        attribute oxygenLevel : OxygenConcentration;
    }
    
    port def VentilatorPort {
        attribute deliveryPressure : PressureValue;
        attribute deliveryFlow : AirFlowRate;
        attribute fiO2 : OxygenConcentration;
    }
    
    port def CuffInflationPort {
        attribute pressure : CuffPressure;
    }
    
    item def Patient {
        port airway : AirwayPort;
        attribute tracheaDiameter : TubeDiameter;
        attribute lungCompliance : Real;
        attribute oxygenSaturation : Real;
    }
    
    item def Ventilator {
        port gasOutlet : VentilatorPort;
        attribute setTidalVolume : TidalVolume;
        attribute setRate : RespiratoryRate;
        attribute setFiO2 : OxygenConcentration;
        attribute peakPressure : PressureValue;
    }
    
    part def TrachealTube {
        attribute innerDiameter : TubeDiameter;
        attribute outerDiameter : TubeDiameter;
        attribute tubeLength : LengthValue;
        attribute cuffPressure : CuffPressure;
        attribute status : TubeStatus;
        
        port proximalEnd : VentilatorPort;
        port distalEnd : AirwayPort;
        port cuffPort : CuffInflationPort;
        
        part lumen {
            attribute effectiveDiameter : TubeDiameter = innerDiameter;
            attribute flowResistance : Real;
        }
        
        part inflatabletCuff {
            attribute currentPressure : CuffPressure = cuffPressure;
            attribute cuffVolume : VolumeValue;
            attribute sealEfficiency : Real;
        }
        
        part murphyEye {
            attribute openingSize : TubeDiameter;
        }
        
        part beveledTip {
            attribute tipAngle : Real;
        }
        
        assert constraint cuffPressureSafety {
            cuffPressure >= 20.0 [Pa] and cuffPressure <= 30.0 [Pa]
        }
        
        assert constraint diameterRelation {
            innerDiameter < outerDiameter
        }
    }
    
    action def PrepareTube {
        in tube : TrachealTube;
        out ready : Boolean;
    }
    
    action def InsertTube {
        in patient : Patient;
        in tube : TrachealTube;
        out insertionDepth : LengthValue;
        out success : Boolean;
    }
    
    action def InflateCuff {
        in targetPressure : CuffPressure;
        inout tube : TrachealTube;
        out achievedPressure : CuffPressure;
    }
    
    action def DeliverBreath {
        in tidalVolume : TidalVolume;
        in fiO2 : OxygenConcentration;
        inout tube : TrachealTube;
        out deliveredVolume : TidalVolume;
        out peakPressure : PressureValue;
    }
    
    action def MonitorAirway {
        in tube : TrachealTube;
        out pressure : PressureValue;
        out flow : AirFlowRate;
        out patency : Boolean;
    }
    
    action def DeflateCuff {
        inout tube : TrachealTube;
    }
    
    action def RemoveTube {
        in tube : TrachealTube;
        in patient : Patient;
        out success : Boolean;
    }
    
    action def ManageAirway {
        first start;
        then action prepare : PrepareTube;
        then action insert : InsertTube;
        then action inflateCuff : InflateCuff {
            in targetPressure = 25.0 [Pa];
        }
        then merge ventilationLoop;
        then action monitor : MonitorAirway;
        then decide;
            if monitor.patency == true then deliverBreath;
            if monitor.patency == false then clearObstruction;
        action deliverBreath : DeliverBreath {
            in tidalVolume = 0.0005 [m^3];
            in fiO2 = 0.5;
        }
        then ventilationLoop;
        action clearObstruction;
        then ventilationLoop;
        then action deflateCuff : DeflateCuff;
        then action remove : RemoveTube;
        then done;
    }
    
    part trachealTubeSystem {
        part tube : TrachealTube {
            attribute :>> innerDiameter = 7.5 [mm];
            attribute :>> outerDiameter = 10.0 [mm];
            attribute :>> tubeLength = 300.0 [mm];
            attribute :>> cuffPressure = 25.0 [Pa];
            attribute :>> status = TubeStatus::stored;
        }
        
        item patient : Patient {
            attribute :>> tracheaDiameter = 18.0 [mm];
            attribute :>> lungCompliance = 50.0;
            attribute :>> oxygenSaturation = 0.95;
        }
        
        item ventilator : Ventilator {
            attribute :>> setTidalVolume = 0.0005 [m^3];
            attribute :>> setRate = 0.2 [Hz];
            attribute :>> setFiO2 = 0.5;
            attribute :>> peakPressure = 25.0 [Pa];
        }
        
        connection ventilatorConnection connect ventilator.gasOutlet to tube.proximalEnd;
        connection patientConnection connect tube.distalEnd to patient.airway;
        
        perform action airwayManagement : ManageAirway;
    }
    
    requirement <'REQ-TT-001'> primaryFunction {
        doc /* The tracheal tube system shall establish and maintain a secure 
             * artificial airway to enable mechanical ventilation, ensuring 
             * adequate oxygenation and ventilation of the patient's lungs.
             */
        subject system :> trachealTubeSystem;
    }
    
    requirement <'REQ-TT-002'> cuffSealRequirement {
        doc /* The inflatable cuff shall create an effective seal against the 
             * tracheal wall to prevent air leakage and aspiration while 
             * maintaining pressure within safe limits to avoid tracheal injury.
             */
        subject cuff :> trachealTubeSystem.tube.inflatabletCuff;
        assert constraint {
            cuff.currentPressure >= 20.0 [Pa] and 
            cuff.currentPressure <= 30.0 [Pa]
        }
    }
    
    requirement <'REQ-TT-003'> airwayPatency {
        doc /* The tube lumen shall maintain unobstructed airflow with minimal 
             * resistance to ensure adequate gas exchange and ventilation.
             */
        subject lumen :> trachealTubeSystem.tube.lumen;
        assert constraint {
            lumen.flowResistance < 5.0
        }
    }
    
    requirement <'REQ-TT-004'> ventilationDelivery {
        doc /* The system shall deliver prescribed tidal volumes and oxygen 
             * concentrations to maintain patient oxygenation above 90% saturation.
             */
        subject system :> trachealTubeSystem;
        subject ventilator :> trachealTubeSystem.ventilator;
        assert constraint {
            ventilator.setTidalVolume >= 0.0003 [m^3] and 
            ventilator.setTidalVolume <= 0.0008 [m^3]
        }
    }
    
    requirement <'REQ-TT-005'> patientSafety {
        doc /* The tracheal tube shall be appropriately sized for the patient 
             * airway to minimize insertion trauma and ensure proper fit.
             */
        subject tube :> trachealTubeSystem.tube;
        subject patient :> trachealTubeSystem.patient;
        assert constraint {
            tube.outerDiameter < patient.tracheaDiameter
        }
    }
    
    requirement <'REQ-TT-006'> pressureSafety {
        doc /* Peak airway pressure during ventilation shall not exceed safe 
             * limits to prevent barotrauma to the lungs.
             */
        subject ventilator :> trachealTubeSystem.ventilator;
        assert constraint {
            ventilator.peakPressure <= 35.0 [Pa]
        }
    }
    
    satisfy primaryFunction by trachealTubeSystem;
    satisfy cuffSealRequirement by trachealTubeSystem.tube.inflatabletCuff;
    satisfy airwayPatency by trachealTubeSystem.tube.lumen;
    satisfy ventilationDelivery by trachealTubeSystem.airwayManagement;
    satisfy patientSafety by trachealTubeSystem.tube;
    satisfy pressureSafety by trachealTubeSystem.ventilator;
}
