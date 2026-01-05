package 'DoubleLumenEndobronchialTubeSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LungSide {
        attribute isLeft : Boolean;
        attribute isRight : Boolean;
    }

    attribute def VentilationMode {
        attribute bothLungs : Boolean;
        attribute leftOnly : Boolean;
        attribute rightOnly : Boolean;
    }

    item def VentilationGas {
        attribute oxygenConcentration : Real;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }

    port def VentilatorPort {
        out gas : VentilationGas;
    }

    port def LumenPort {
        inout gas : VentilationGas;
    }

    port def LungPort {
        in gas : VentilationGas;
        out compliance : Real;
    }

    part def BronchialCuff {
        attribute inflationPressure : PressureValue;
        attribute isInflated : Boolean := false;
        attribute diameter : LengthValue;

        action def InflateCuff {
            in targetPressure : PressureValue;
            out sealed : Boolean;

            first start;
            then assign inflationPressure := targetPressure;
            then assign isInflated := true;
            then assign sealed := true;
            then done;
        }

        action def DeflateCuff {
            out released : Boolean;

            first start;
            then assign inflationPressure := 0.0 [SI::Pa];
            then assign isInflated := false;
            then assign released := true;
            then done;
        }
    }

    part def TrachealCuff {
        attribute inflationPressure : PressureValue;
        attribute isInflated : Boolean := false;
        attribute diameter : LengthValue;

        action def InflateCuff {
            in targetPressure : PressureValue;
            out sealed : Boolean;

            first start;
            then assign inflationPressure := targetPressure;
            then assign isInflated := true;
            then assign sealed := true;
            then done;
        }

        action def DeflateCuff {
            out released : Boolean;

            first start;
            then assign inflationPressure := 0.0 [SI::Pa];
            then assign isInflated := false;
            then assign released := true;
            then done;
        }
    }

    part def Lumen {
        attribute innerDiameter : LengthValue;
        attribute length : LengthValue;
        port proximal : LumenPort;
        port distal : LumenPort;
    }

    part def DoubleLumenTube {
        attribute tubeSize : LengthValue;
        attribute insertionDepth : LengthValue;

        part bronchialLumen : Lumen {
            attribute :>> innerDiameter = 4.0 [mm];
            attribute :>> length = 320.0 [mm];
        }

        part trachealLumen : Lumen {
            attribute :>> innerDiameter = 5.0 [mm];
            attribute :>> length = 320.0 [mm];
        }

        part bronchialCuff : BronchialCuff {
            attribute :>> diameter = 7.5 [mm];
        }

        part trachealCuff : TrachealCuff {
            attribute :>> diameter = 11.0 [mm];
        }

        port ventilatorInput : VentilatorPort;
        port leftLungOutput : LumenPort;
        port rightLungOutput : LumenPort;
    }

    part def Ventilator {
        attribute tidalVolume : VolumeValue;
        attribute respiratoryRate : FrequencyValue;
        attribute peakPressure : PressureValue;
        attribute fiO2 : Real;

        port leftOutput : VentilatorPort;
        port rightOutput : VentilatorPort;

        action def DeliverBreath {
            in mode : VentilationMode;
            in volume : VolumeValue;
            in pressure : PressureValue;
            in oxygenLevel : Real;
            out leftGas : VentilationGas;
            out rightGas : VentilationGas;

            first start;
            then decide;
                if mode.bothLungs then deliverBilateral;
                if mode.leftOnly then deliverLeftOnly;
                if mode.rightOnly then deliverRightOnly;

            action deliverBilateral {
                then assign leftGas.flowRate := volume / 2.0 [s];
                then assign rightGas.flowRate := volume / 2.0 [s];
                then assign leftGas.pressure := pressure;
                then assign rightGas.pressure := pressure;
                then assign leftGas.oxygenConcentration := oxygenLevel;
                then assign rightGas.oxygenConcentration := oxygenLevel;
            }
            then merge complete;

            action deliverLeftOnly {
                then assign leftGas.flowRate := volume / 1.0 [s];
                then assign rightGas.flowRate := 0.0 [L/s];
                then assign leftGas.pressure := pressure;
                then assign rightGas.pressure := 0.0 [Pa];
                then assign leftGas.oxygenConcentration := oxygenLevel;
                then assign rightGas.oxygenConcentration := 0.0;
            }
            then complete;

            action deliverRightOnly {
                then assign leftGas.flowRate := 0.0 [L/s];
                then assign rightGas.flowRate := volume / 1.0 [s];
                then assign leftGas.pressure := 0.0 [Pa];
                then assign rightGas.pressure := pressure;
                then assign leftGas.oxygenConcentration := 0.0;
                then assign rightGas.oxygenConcentration := oxygenLevel;
            }
            then complete;

            then done;
        }
    }

    part def Lung {
        attribute side : LungSide;
        attribute compliance : Real;
        attribute resistance : Real;
        attribute isCollapsed : Boolean := false;

        port airwayConnection : LungPort;

        action def ReceiveVentilation {
            in incomingGas : VentilationGas;
            out lungPressure : PressureValue;
            out ventilationEffective : Boolean;

            first start;
            then decide;
                if isCollapsed then noVentilation;
                else normalVentilation;

            action noVentilation {
                then assign lungPressure := 0.0 [Pa];
                then assign ventilationEffective := false;
            }
            then merge finish;

            action normalVentilation {
                then assign lungPressure := incomingGas.pressure;
                then assign ventilationEffective := true;
            }
            then finish;

            then done;
        }
    }

    action def EstablishLungIsolation {
        in targetLung : LungSide;
        in tube : DoubleLumenTube;
        out isolationComplete : Boolean;

        first start;
        then action positionTube {
            in depth : LengthValue;
            out positioned : Boolean;

            assign tube.insertionDepth := depth;
            assign positioned := true;
        }
        then action inflateTrachealCuff : tube.trachealCuff.InflateCuff {
            in targetPressure = 3300.0 [Pa];
            out sealed;
        }
        then action inflateBronchialCuff : tube.bronchialCuff.InflateCuff {
            in targetPressure = 2700.0 [Pa];
            out sealed;
        }
        then action verifyIsolation {
            in trachealSealed : Boolean = inflateTrachealCuff.sealed;
            in bronchialSealed : Boolean = inflateBronchialCuff.sealed;
            out verified : Boolean;

            assign verified := trachealSealed and bronchialSealed;
            assign isolationComplete := verified;
        }
        then done;
    }

    action def PerformSelectiveLungVentilation {
        in operativeLung : LungSide;
        in ventilator : Ventilator;
        in leftLung : Lung;
        in rightLung : Lung;
        out ventilationStatus : VentilationMode;

        first start;
        then merge ventilationCycle;
        then action determineMode {
            in operative : LungSide = operativeLung;
            out mode : VentilationMode;

            decide;
                if operative.isLeft then assign mode.rightOnly := true;
                if operative.isRight then assign mode.leftOnly := true;
        }
        then action deliverVentilation : ventilator.DeliverBreath {
            in mode = determineMode.mode;
            in volume = ventilator.tidalVolume;
            in pressure = ventilator.peakPressure;
            in oxygenLevel = ventilator.fiO2;
            out leftGas;
            out rightGas;
        }
        then action ventilateLeftLung : leftLung.ReceiveVentilation {
            in incomingGas = deliverVentilation.leftGas;
            out lungPressure;
            out ventilationEffective;
        }
        then action ventilateRightLung : rightLung.ReceiveVentilation {
            in incomingGas = deliverVentilation.rightGas;
            out lungPressure;
            out ventilationEffective;
        }
        then action monitorOxygenation {
            in leftEffective : Boolean = ventilateLeftLung.ventilationEffective;
            in rightEffective : Boolean = ventilateRightLung.ventilationEffective;
            out adequate : Boolean;

            assign adequate := leftEffective or rightEffective;
        }
        then decide;
            if monitorOxygenation.adequate then ventilationCycle;
            else adjustParameters;

        action adjustParameters {
            out adjusted : Boolean;
            assign adjusted := true;
        }
        then ventilationCycle;
    }

    part doubleLumenSystem {
        part dlt : DoubleLumenTube {
            attribute :>> tubeSize = 12.3 [mm];
            attribute :>> insertionDepth = 290.0 [mm];
        }

        part ventilator : Ventilator {
            attribute :>> tidalVolume = 0.45 [L];
            attribute :>> respiratoryRate = 0.233 [Hz];
            attribute :>> peakPressure = 2200.0 [Pa];
            attribute :>> fiO2 = 0.8;
        }

        part leftLung : Lung {
            attribute :>> side.isLeft = true;
            attribute :>> side.isRight = false;
            attribute :>> compliance = 0.06;
            attribute :>> resistance = 2.0;
        }

        part rightLung : Lung {
            attribute :>> side.isLeft = false;
            attribute :>> side.isRight = true;
            attribute :>> compliance = 0.06;
            attribute :>> resistance = 2.0;
        }

        connect ventilator.leftOutput to dlt.ventilatorInput;
        connect dlt.leftLungOutput to leftLung.airwayConnection;
        connect dlt.rightLungOutput to rightLung.airwayConnection;

        perform action manageLungVentilation : PerformSelectiveLungVentilation {
            in operativeLung.isLeft = true;
            in ventilator = doubleLumenSystem.ventilator;
            in leftLung = doubleLumenSystem.leftLung;
            in rightLung = doubleLumenSystem.rightLung;
            out ventilationStatus;
        }
    }

    requirement <'DLT-REQ-001'> lungIsolationRequirement {
        doc /* The double-lumen endobronchial tube shall provide complete physical 
             isolation between the left and right lungs to enable independent 
             ventilation control. */

        subject tube : DoubleLumenTube;

        require constraint {
            tube.bronchialCuff.isInflated and tube.trachealCuff.isInflated
        }
    }

    requirement <'DLT-REQ-002'> selectiveVentilationRequirement {
        doc /* The system shall enable selective ventilation of either the left lung 
             alone, right lung alone, or both lungs simultaneously as determined by 
             clinical need. */

        subject system : doubleLumenSystem;
    }

    requirement <'DLT-REQ-003'> cuffPressureSafetyRequirement {
        doc /* Cuff inflation pressures shall be maintained between 2000-4000 Pa to 
             ensure adequate airway seal while preventing mucosal ischemia and 
             tissue damage. */

        subject tube : DoubleLumenTube;
    }

    requirement <'DLT-REQ-004'> airwayPressureLimitRequirement {
        doc /* Peak airway pressures shall not exceed 3500 Pa during ventilation 
             to prevent barotrauma to lung tissue. */

        subject vent : Ventilator;
    }

    requirement primaryFunctionRequirement {
        doc /* The double-lumen endobronchial tube system shall provide independent 
             lung ventilation capability for thoracic surgical procedures requiring 
             lung isolation. The system enables selective collapse of one lung while 
             maintaining adequate oxygenation and ventilation of the contralateral 
             lung, facilitating surgical access and preventing contamination between 
             lung compartments. */

        subject system : doubleLumenSystem;

        require lungIsolationRequirement;
        require selectiveVentilationRequirement;
        require cuffPressureSafetyRequirement;
        require airwayPressureLimitRequirement;
    }
}
