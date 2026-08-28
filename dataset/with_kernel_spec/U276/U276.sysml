package LaryngealTubeAirwaySystem {
    private import ISQ::*;
    private import ScalarValues::*;

    value def Pressure :> ISQ::pressure;
    value def Volume :> ISQ::volume;
    value def Length :> ISQ::length;
    value def FlowRate :> ISQ::volumeFlowRate;
    attribute def TubeSizeCode : String;

    item def Air;
    item def AirMixture;
    item def GastricContent;

    port def VentilationPort {
        in item inspiredAir : AirMixture;
        out item exhaledAir : AirMixture;
    }
    port def InflationPort {
        in item inflationAir : Air;
    }
    port def MonitoringPort {
        out attribute pressure : Pressure;
    }

    part def Cuff {
        attribute targetPressure : Pressure;
        attribute currentPressure : Pressure;
        attribute isInflated : Boolean;
        port inflationIn : InflationPort;
        action inflate;
        action deflate;
    }

    part def InflationLine {
        port inlet : InflationPort;
        port outletProximal : InflationPort;
        port outletDistal : InflationPort;
        port outletPilot : InflationPort;
    }

    part def VentilationLumen {
        port inlet : VentilationPort;
        port outlet : VentilationPort;
        attribute innerDiameter : Length;
    }

    part def PilotBalloon {
        attribute isExpanded : Boolean;
        port inlet : InflationPort;
        action indicatePressure;
    }

    part def DistalTip;

    part def LaryngealTubeDevice {
        attribute sizeCode : TubeSizeCode;
        attribute material : String = "Medical-grade silicone";
        attribute tubeLength : Length;
        attribute maxCuffPressure : Pressure;

        part proximalCuff : Cuff;
        part distalCuff : Cuff;
        part ventilationLumen : VentilationLumen;
        part inflationLine : InflationLine;
        part pilotBalloon : PilotBalloon;
        part distalTip : DistalTip;

        port inflationPort : InflationPort;
        port ventilationPort : VentilationPort;
        port monitoringPort : MonitoringPort;

        connect inflationPort to inflationLine.inlet;
        connect inflationLine.outletProximal to proximalCuff.inflationIn;
        connect inflationLine.outletDistal to distalCuff.inflationIn;
        connect inflationLine.outletPilot to pilotBalloon.inlet;
        connect ventilationPort to ventilationLumen.inlet;
    }

    part def InflationSyringe {
        attribute capacity : Volume;
        port outputPort : InflationPort;
        action injectAir;
    }

    part def VentilationSource {
        attribute sourceType : String;
        port outputPort : VentilationPort;
        action deliverBreath;
    }

    part def MonitoringSystem {
        port inputPort : MonitoringPort;
        attribute measuredPressure : Pressure;
        attribute leakDetected : Boolean;
        action monitorAirway;
        action detectLeak;
    }

    part def Oropharynx;
    part def Esophagus;
    part def Trachea;
    part def Lungs;

    part def Patient {
        part oropharynx : Oropharynx;
        part esophagus : Esophagus;
        part trachea : Trachea;
        part lungs : Lungs;
        port airwayPort : VentilationPort;
    }

    occurrence def InsertTube;
    occurrence def InflateCuffs;
    occurrence def VerifyPlacement;
    occurrence def DeflateCuffs;
    occurrence def RemoveTube;

    connection def CuffSeal {
        end cuff : Cuff;
        end tissue : Oropharynx;
    }

    connection def EsophagealSeal {
        end cuff : Cuff;
        end tissue : Esophagus;
    }

    part airwaySystem {
        part tube : LaryngealTubeDevice;
        part syringe : InflationSyringe;
        part ventSource : VentilationSource;
        part monitor : MonitoringSystem;
        part patient : Patient;

        connect syringe.outputPort to tube.inflationPort;
        connect ventSource.outputPort to tube.ventilationPort;
        connect monitor.inputPort to tube.monitoringPort;
        connect tube.ventilationLumen.outlet to patient.airwayPort;

        connection : CuffSeal connect tube.proximalCuff to patient.oropharynx;
        connection : EsophagealSeal connect tube.distalCuff to patient.esophagus;

        state airwayManagement {
            entry; then ready;
            state ready;
            accept InsertTube then inserted;
            state inserted;
            accept InflateCuffs then sealed;
            state sealed;
            accept VerifyPlacement then ventilating;
            state ventilating;
            accept DeflateCuffs then deflated;
            state deflated;
            accept RemoveTube then ready;
        }
    }

    requirement def 'Dual Cuff Seal' {
        doc /* The device shall feature a proximal oropharyngeal cuff and a distal esophageal cuff that inflate simultaneously. */
    }
    requirement def 'Prevent Gastric Aspiration' {
        doc /* The distal cuff shall prevent stomach contents from being aspirated into the lungs. */
    }
    requirement def 'Single Port Inflation' {
        doc /* A single inflation port shall inflate both cuffs simultaneously via an internal line. */
    }
    requirement def 'Pilot Balloon Indicator' {
        doc /* A pilot balloon shall provide visual and tactile indication of cuff pressure. */
    }
    requirement def 'Continuous Ventilation' {
        doc /* The system shall allow continuous ventilation and monitoring of airway pressure. */
    }
    requirement def 'Safe Removal' {
        doc /* The system shall allow cuff deflation and safe removal without trauma. */
    }

    requirement dualCuffSealReq : 'Dual Cuff Seal';
    requirement preventAspirationReq : 'Prevent Gastric Aspiration';
    requirement singlePortReq : 'Single Port Inflation';
    requirement pilotBalloonReq : 'Pilot Balloon Indicator';
    requirement continuousVentReq : 'Continuous Ventilation';
    requirement safeRemovalReq : 'Safe Removal';
}
