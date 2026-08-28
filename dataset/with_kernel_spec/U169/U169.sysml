package BlindInsertionAirwayDevice {
    unit def mmHg;
    unit def mL;
    unit def cm;
    unit def mm;
    unit def percent;
    unit def kg;

    value def Pressure :> Real { unit mmHg; }
    value def Volume :> Real { unit mL; }
    value def TubeLength :> Real { unit cm; }
    value def TubeDiameter :> Real { unit mm; }
    value def SpO2Value :> Real { unit percent; }
    value def EtCO2Value :> Real { unit mmHg; }
    value def MassValue :> Real { unit kg; }

    enum def TubeSize {
        size_3;
        size_4;
        size_5;
    }

    enum def CuffType {
        pharyngeal;
        esophageal;
    }

    item def Air;
    item def Oxygen;
    item def OxygenMixture;
    item def ExhaledGas;
    item def StomachContents;

    port def AirwayPort {
        in item ventilation : Air;
        out item exhalation : ExhaledGas;
    }

    port def GasPort {
        in item gasIn : Oxygen;
        out item gasOut : OxygenMixture;
    }

    port def CuffPort {
        in item inflationAir : Air;
        attribute cuffPressure : Pressure;
    }

    port def SensorPort {
        attribute spo2 : SpO2Value;
        attribute etco2 : EtCO2Value;
    }

    part def Patient {
        attribute patientMass : MassValue = 70[kg];
        attribute oxygenSaturation : SpO2Value = 98[percent];
        attribute endTidalCO2 : EtCO2Value = 40[mmHg];
        port airway : AirwayPort;
        port sensorOutput : SensorPort;
    }

    part def Cuff {
        attribute cuffType : CuffType;
        attribute targetVolume : Volume;
        attribute maxSafePressure : Pressure;
        attribute currentVolume : Volume = 0[mL];
        attribute currentPressure : Pressure = 0[mmHg];
        port inflationPort : CuffPort;
    }

    part def BIADTube {
        attribute size : TubeSize = TubeSize::size_4;
        attribute tubeLength : TubeLength = 22[cm];
        attribute outerDiameter : TubeDiameter = 13[mm];
        port proximal : AirwayPort;
        port distal : AirwayPort;
        part pharyngealCuff : Cuff {
            :>> cuffType = CuffType::pharyngeal;
            :>> targetVolume = 85[mL];
            :>> maxSafePressure = 60[mmHg];
        }
        part esophagealCuff : Cuff {
            :>> cuffType = CuffType::esophageal;
            :>> targetVolume = 15[mL];
            :>> maxSafePressure = 45[mmHg];
        }
        port pharyngealCuffPort : CuffPort;
        port esophagealCuffPort : CuffPort;
        connect pharyngealCuffPort to pharyngealCuff.inflationPort;
        connect esophagealCuffPort to esophagealCuff.inflationPort;
    }

    part def InflationSyringe {
        attribute maxVolume : Volume = 100[mL];
        attribute currentVolume : Volume = 100[mL];
        port outputPort : CuffPort;
    }

    part def PressureManometer {
        attribute reading : Pressure = 0[mmHg];
        port measurementPort : CuffPort;
    }

    part def VentilationBag {
        attribute bagVolume : Volume = 1600[mL];
        attribute squeezeRate : Real = 12;
        port inletPort : GasPort;
        port outletPort : AirwayPort;
    }

    part def OxygenSource {
        attribute tankPressure : Pressure = 2000[mmHg];
        attribute flowRate : Real = 15;
        port outputPort : GasPort;
    }

    part def PatientMonitor {
        attribute spo2Reading : SpO2Value = 0[percent];
        attribute etCO2Reading : EtCO2Value = 0[mmHg];
        port sensorInput : SensorPort;
    }

    part def Operator;

    action def InsertDevice {
        in part patient : Patient;
        in part tube : BIADTube;
    }

    action def InflateCuffs {
        in part syringe : InflationSyringe;
        in part tube : BIADTube;
        in part manometer : PressureManometer;
    }

    action def VerifyPlacement {
        in part monitor : PatientMonitor;
        in part patient : Patient;
    }

    action def Ventilate {
        in part bag : VentilationBag;
        in part tube : BIADTube;
        in part patient : Patient;
    }

    action def MonitorPatient {
        in part monitor : PatientMonitor;
        in part patient : Patient;
    }

    state def BIADLifecycle {
        state standby;
        state inserting {
            entry action insertAction : InsertDevice;
        }
        state inflating {
            entry action inflateAction : InflateCuffs;
        }
        state verifying {
            entry action verifyAction : VerifyPlacement;
        }
        state ventilating {
            entry action ventilateAction : Ventilate;
        }
        state monitoring {
            entry action monitorAction : MonitorPatient;
        }
        initial -> standby;
        standby -> inserting;
        inserting -> inflating;
        inflating -> verifying;
        verifying -> ventilating;
        ventilating -> monitoring;
        monitoring -> ventilating;
    }

    part def BIADSystem {
        part tube : BIADTube;
        part syringe : InflationSyringe;
        part manometer : PressureManometer;
        part ventilationBag : VentilationBag;
        part oxygenSource : OxygenSource;
        part monitor : PatientMonitor;
        part patient : Patient;

        connect syringe.outputPort to tube.pharyngealCuffPort;
        connect syringe.outputPort to tube.esophagealCuffPort;
        connect manometer.measurementPort to tube.pharyngealCuffPort;
        connect manometer.measurementPort to tube.esophagealCuffPort;
        connect oxygenSource.outputPort to ventilationBag.inletPort;
        connect ventilationBag.outletPort to tube.proximal;
        connect tube.distal to patient.airway;
        connect monitor.sensorInput to patient.sensorOutput;

        state lifecycle : BIADLifecycle;
    }

    requirement def RapidAirwayEstablishment {
        subject patient : Patient;
        objective {
            /* The BIAD system shall establish a breathable airway within 30 seconds of deployment. */
        }
    }

    requirement def CuffSealIntegrity {
        subject tube : BIADTube;
        objective {
            /* The pharyngeal cuff shall seal the upper pharynx and the esophageal cuff shall block the esophagus when inflated. */
        }
    }

    requirement def SafeCuffPressure {
        subject cuff : Cuff;
        objective {
            /* Cuff pressure shall not exceed the maximum safe pressure to prevent tissue damage. */
        }
    }

    requirement def PlacementVerification {
        subject monitor : PatientMonitor;
        objective {
            /* The patient monitor shall confirm correct tube placement via oxygen saturation and end-tidal CO2. */
        }
    }

    requirement def TubeSizeAvailability {
        subject tube : BIADTube;
        objective {
            /* The BIAD tube shall be available in sizes 3, 4, and 5 to fit various patients. */
        }
    }

    use case def InsertUC;
    use case def InflateUC;
    use case def VerifyUC;
    use case def VentilateUC;
    use case def MonitorUC;

    use case def DeployBIAD {
        subject biad : BIADSystem;
        actor paramedic : Operator;
        actor patient : Patient;
        objective {
            /* Rapidly establish and maintain a breathable airway for the patient without direct visualization. */
        }
        include use case insertUC1 : InsertUC;
        include use case inflateUC1 : InflateUC;
        include use case verifyUC1 : VerifyUC;
        include use case ventilateUC1 : VentilateUC;
        include use case monitorUC1 : MonitorUC;
    }

    individual def StandardBIAD :> BIADSystem;

    individual standardBIAD : StandardBIAD {
        :>> tube {
            :>> size = TubeSize::size_4;
            :>> tubeLength = 22[cm];
            :>> outerDiameter = 13[mm];
        }
        :>> syringe {
            :>> maxVolume = 100[mL];
        }
        :>> oxygenSource {
            :>> tankPressure = 2000[mmHg];
            :>> flowRate = 15;
        }
        :>> ventilationBag {
            :>> bagVolume = 1600[mL];
            :>> squeezeRate = 12;
        }
        :>> patient {
            :>> patientMass = 70[kg];
        }
    }

    part biadSystem : BIADSystem {
        satisfy RapidAirwayEstablishment;
        satisfy CuffSealIntegrity;
        satisfy SafeCuffPressure;
        satisfy PlacementVerification;
        satisfy TubeSizeAvailability;
    }
}
