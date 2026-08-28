package ProtectedPCI {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    value def PressureUnit :> Real { unit 'mmHg'; }
    value def FlowRateUnit :> Real { unit 'L/min'; }
    value def RotationalSpeedUnit :> Real { unit 'RPM'; }
    value def HeartRateUnit :> Real { unit 'bpm'; }
    value def OxygenSaturationUnit :> Real { unit '%'; }
    value def VolumeUnit :> Real { unit 'mL'; }
    value def DiameterUnit :> Real { unit 'mm'; }
    value def LengthUnit :> Real { unit 'cm'; }
    value def PowerUnit :> Real { unit 'W'; }
    value def FrequencyUnit :> Real { unit 'Hz'; }
    value def CurrentUnit :> Real { unit 'A'; }
    value def TemperatureUnit :> Real { unit 'degC'; }
    
    value def Pressure :> Real { unit PressureUnit; }
    value def FlowRate :> Real { unit FlowRateUnit; }
    value def RotationalSpeed :> Real { unit RotationalSpeedUnit; }
    value def HeartRate :> Real { unit HeartRateUnit; }
    value def OxygenSaturation :> Real { unit OxygenSaturationUnit; }
    value def Volume :> Real { unit VolumeUnit; }
    value def Diameter :> Real { unit DiameterUnit; }
    value def Length :> Real { unit LengthUnit; }
    value def Power :> Real { unit PowerUnit; }
    value def Frequency :> Real { unit FrequencyUnit; }
    value def Current :> Real { unit CurrentUnit; }
    value def Temperature :> Real { unit TemperatureUnit; }
    
    // ===== Items =====
    item def Blood;
    item def ContrastAgent;
    item def SalineSolution;
    item def PlaqueDebris;
    
    // ===== Signal/Message Items =====
    item def PumpCommand { 
        attribute targetSpeed : RotationalSpeed;
        attribute mode : String;
    }
    item def PumpStatus {
        attribute currentSpeed : RotationalSpeed;
        attribute flowRate : FlowRate;
        attribute powerDraw : Power;
        attribute state : String;
    }
    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute systolicBP : Pressure;
        attribute diastolicBP : Pressure;
        attribute oxygenSat : OxygenSaturationUnit;
        attribute meanArterialPressure : Pressure;
    }
    item def AlertMessage {
        attribute severity : String;
        attribute parameter : String;
        attribute threshold : Real;
        attribute measured : Real;
    }
    item def FluoroImage {
        attribute frameRate : Frequency;
        attribute resolution : String;
    }
    item def ConsoleDisplay {
        attribute pumpStatus : PumpStatus;
        attribute vitals : VitalSigns;
        attribute fluoroImage : FluoroImage;
    }
    
    // ===== Port Definitions =====
    port def BloodFlowPort {
        out item blood : Blood;
    }
    port def FluidFlowPort {
        out item fluid : SalineSolution;
    }
    port def ContrastPort {
        out item contrast : ContrastAgent;
    }
    port def ControlPort {
        in item command : PumpCommand;
        out item status : PumpStatus;
    }
    port def MonitoringPort {
        out item vitals : VitalSigns;
        out item alert : AlertMessage;
    }
    port def ImagingPort {
        out item image : FluoroImage;
    }
    port def DisplayPort {
        out item display : ConsoleDisplay;
    }
    port def ElectricalPowerPort {
        in attribute voltage : Real;
        in attribute current : Current;
    }
    
    // ===== Requirements =====
    requirement def ProtectedPCIRequirement {
        doc "The system shall enable safe percutaneous coronary intervention on patients with severe coronary artery disease and compromised left ventricular function.";
    }
    
    requirement def HemodynamicStabilityRequirement :> ProtectedPCIRequirement {
        subject patient : Patient;
        doc "The MCS device shall maintain mean arterial pressure above 65 mmHg during the procedure.";
        require { patient.meanArterialPressure >= 65.0; }
    }
    
    requirement def FlowSupportRequirement :> ProtectedPCIRequirement {
        subject pump : MCSPump;
        doc "The MCS pump shall provide up to 5.0 L/min of circulatory support.";
        require { pump.maxFlowRate >= 5.0; }
    }
    
    requirement def MonitoringRequirement :> ProtectedPCIRequirement {
        subject monitor : HemodynamicMonitor;
        doc "The hemodynamic monitor shall continuously track heart rate, blood pressure, and oxygen saturation with alerts within 2 seconds of threshold breach.";
        require { monitor.alertLatency <= 2.0; }
    }
    
    requirement def VisualizationRequirement :> ProtectedPCIRequirement {
        subject fluoro : FluoroscopySystem;
        doc "The fluoroscopy system shall provide real-time imaging at a minimum of 15 frames per second during tool navigation and stent deployment.";
        require { fluoro.minFrameRate >= 15.0; }
    }
    
    requirement def StentDeploymentRequirement :> ProtectedPCIRequirement {
        subject stent : CoronaryStent;
        doc "The coronary stent shall achieve a minimum deployed diameter of 2.5 mm and maintain patency of the treated vessel.";
        require { stent.deployedDiameter >= 2.5; }
    }
    
    // ===== Part Definitions =====
    
    part def Patient {
        attribute meanArterialPressure : Pressure;
        attribute heartRate : HeartRate;
        attribute oxygenSaturation : OxygenSaturation;
        
        part leftVentricle {
            port ventriclePort : BloodFlowPort;
            attribute ejectionFraction : Real;
        }
        part aorta {
            port aortaPort : BloodFlowPort;
        }
        part coronaryArtery {
            port proximalPort : BloodFlowPort;
            port distalPort : BloodFlowPort;
            attribute blockageSeverity : Real;
            attribute vesselDiameter : Diameter;
        }
        part femoralArtery {
            port accessPort : BloodFlowPort;
        }
    }
    
    part def MCSPump {
        attribute maxFlowRate : FlowRate := 5.0;
        attribute maxSpeed : RotationalSpeed := 60000;
        attribute currentSpeed : RotationalSpeed;
        attribute currentFlow : FlowRate;
        attribute powerDraw : Power;
        attribute inletDiameter : Diameter := 12.0;
        attribute outletDiameter : Diameter := 10.0;
        attribute catheterLength : Length := 100.0;
        
        port inletPort : BloodFlowPort;
        port outletPort : BloodFlowPort;
        port controlPort : ControlPort;
        port powerPort : ElectricalPowerPort;
        
        part impeller {
            attribute bladeCount : Integer := 3;
            attribute material : String := "titanium alloy";
        }
        part motor {
            attribute ratedPower : Power := 45.0;
        }
        part cannula {
            attribute length : Length := 100.0;
            attribute outerDiameter : Diameter := 14.0;
        }
        part purgeCircuit {
            port purgePort : FluidFlowPort;
            attribute purgeRate : FlowRate := 0.02;
        }
        
        state def PumpState {
            initial standby;
            state priming;
            state activeSupport;
            state weaning;
            state faulted;
            
            transition standby to priming
                when (controlPort.command.mode == "prime")
                do { purgeCircuit.purgePort.fluid.send(); };
            
            transition priming to activeSupport
                when (controlPort.command.mode == "activate")
                do { currentSpeed := controlPort.command.targetSpeed; };
            
            transition activeSupport to activeSupport
                when (controlPort.command.mode == "ramp")
                do { currentSpeed := controlPort.command.targetSpeed; currentFlow := currentSpeed * 0.00008; };
            
            transition activeSupport to weaning
                when (controlPort.command.mode == "wean")
                do { currentSpeed := currentSpeed * 0.5; };
            
            transition weaning to standby
                when (controlPort.command.mode == "stop")
                do { currentSpeed := 0.0; currentFlow := 0.0; };
            
            transition standby, priming, activeSupport, weaning to faulted
                when (powerPort.current == 0.0 or currentSpeed > maxSpeed)
                do { currentSpeed := 0.0; };
        }
        
        exhibit PumpState;
    }
    
    part def GuideCatheter {
        attribute outerDiameter : Diameter := 2.5;
        attribute innerDiameter : Diameter := 2.0;
        attribute length : Length := 100.0;
        attribute material : String := "braided polymer";
        
        port proximalPort : BloodFlowPort;
        port distalPort : BloodFlowPort;
        port contrastPort : ContrastPort;
        
        part hub {
            attribute luerConnector : String := "standard";
        }
        part shaft {
            attribute flexibility : Real := 0.8;
        }
        part tip {
            attribute curveAngle : Real := 45.0;
        }
    }
    
    part def GuideWire {
        attribute diameter : Diameter := 0.36;
        attribute length : Length := 180.0;
        attribute tipLoad : Real := 1.0;
        attribute coating : String := "hydrophilic";
        
        port proximalEnd;
        port distalTip;
        
        part core {
            attribute material : String := "nitinol";
        }
        part tipSection {
            attribute flexibility : Real := 0.95;
        }
        part coatingLayer {
            attribute thickness : Real := 0.005;
        }
    }
    
    part def BalloonCatheter {
        attribute balloonDiameter : Diameter := 3.0;
        attribute balloonLength : Length := 15.0;
        attribute ratedBurstPressure : Pressure := 18.0;
        attribute shaftDiameter : Diameter := 1.0;
        attribute trackability : Real := 0.9;
        
        port proximalPort;
        port distalPort;
        port inflationPort;
        
        part balloon {
            attribute material : String := "compliant polymer";
            attribute inflatedDiameter : Diameter;
            attribute inflatedPressure : Pressure;
        }
        part shaft {
            attribute length : Length := 140.0;
        }
        part tip {
            attribute taperAngle : Real := 15.0;
        }
        
        action def InflateBalloon {
            in targetPressure : Pressure;
            do { balloon.inflatedPressure := targetPressure; balloon.inflatedDiameter := balloonDiameter; };
        }
        action def DeflateBalloon {
            do { balloon.inflatedPressure := 0.0; balloon.inflatedDiameter := 0.0; };
        }
    }
    
    part def CoronaryStent {
        attribute nominalDiameter : Diameter := 3.0;
        attribute nominalLength : Length := 18.0;
        attribute strutThickness : Real := 0.08;
        attribute material : String := "cobalt-chromium";
        attribute deployedDiameter : Diameter;
        attribute deployed : Boolean := false;
        
        part mesh {
            attribute cellDesign : String := "open cell";
            attribute radialForce : Real := 0.85;
        }
        part drugCoating {
            attribute drug : String := "everolimus";
            attribute doseDensity : Real := 1.0;
        }
        
        action def Deploy {
            in deploymentPressure : Pressure;
            do { deployed := true; deployedDiameter := nominalDiameter; };
        }
    }
    
    part def FluoroscopySystem {
        attribute minFrameRate : Frequency := 30.0;
        attribute maxDose : Real := 50.0;
        attribute resolution : String := "1024x1024";
        
        port imagingPort : ImagingPort;
        
        part xraySource {
            attribute peakVoltage : Real := 80.0;
            attribute current : Current := 500.0;
        }
        part detector {
            attribute type : String := "flat panel";
            attribute pixelSize : Real := 0.2;
        }
        part cArm {
            attribute rotationRange : Real := 180.0;
            attribute tiltRange : Real := 45.0;
        }
        part imageProcessor {
            attribute processingLatency : Real := 0.05;
        }
        
        action def AcquireImage {
            out image : FluoroImage;
            do { image := FluoroImage{frameRate=minFrameRate, resolution=resolution}; imagingPort.image.send(image); };
        }
    }
    
    part def HemodynamicMonitor {
        attribute alertLatency : Real := 1.0;
        attribute samplingRate : Frequency := 500.0;
        attribute hrLowThreshold : HeartRate := 40.0;
        attribute hrHighThreshold : HeartRate := 150.0;
        attribute mapLowThreshold : Pressure := 65.0;
        attribute spo2LowThreshold : OxygenSaturation := 88.0;
        
        port monitoringPort : MonitoringPort;
        
        part pressureTransducer {
            attribute accuracy : Real := 0.5;
        }
        part ecgModule {
            attribute leadCount : Integer := 12;
        }
        part pulseOximeter {
            attribute sensorType : String := "finger clip";
        }
        part alarmUnit {
            attribute volume : Real := 0.8;
        }
        
        action def MonitorVitals {
            in hr : HeartRate;
            in sbp : Pressure;
            in dbp : Pressure;
            in spo2 : OxygenSaturation;
            out vitals : VitalSigns;
            out alert : AlertMessage;
            do {
                vitals := VitalSigns{heartRate=hr, systolicBP=sbp, diastolicBP=dbp, oxygenSat=spo2, meanArterialPressure=(sbp + 2*dbp)/3.0};
                monitoringPort.vitals.send(vitals);
                if (hr < hrLowThreshold) {
                    alert := AlertMessage{severity="critical", parameter="heartRate", threshold=hrLowThreshold, measured=hr};
                    monitoringPort.alert.send(alert);
                }
                if (hr > hrHighThreshold) {
                    alert := AlertMessage{severity="critical", parameter="heartRate", threshold=hrHighThreshold, measured=hr};
                    monitoringPort.alert.send(alert);
                }
                if ((sbp + 2*dbp)/3.0 < mapLowThreshold) {
                    alert := AlertMessage{severity="critical", parameter="MAP", threshold=mapLowThreshold, measured=(sbp + 2*dbp)/3.0};
                    monitoringPort.alert.send(alert);
                }
                if (spo2 < spo2LowThreshold) {
                    alert := AlertMessage{severity="warning", parameter="SpO2", threshold=spo2LowThreshold, measured=spo2};
                    monitoringPort.alert.send(alert);
                }
            }
        }
    }
    
    part def ControlConsole {
        attribute displaySize : String := "24 inch";
        attribute refreshRate : Frequency := 60.0;
        attribute backupBatteryTime : Real := 30.0;
        
        port pumpControlPort : ControlPort;
        port monitorInputPort : MonitoringPort;
        port fluoroInputPort : ImagingPort;
        port displayPort : DisplayPort;
        
        part touchscreen {
            attribute resolution : String := "1920x1080";
        }
        part pumpController {
            attribute maxRampRate : RotationalSpeed := 5000;
        }
        part dataLogger {
            attribute storageCapacity : Real := 500.0;
            attribute samplingInterval : Real := 0.1;
        }
        part emergencyStop {
            attribute type : String := "hardware button";
        }
        
        action def UpdateDisplay {
            in pumpStatus : PumpStatus;
            in vitals : VitalSigns;
            in fluoroImage : FluoroImage;
            out display : ConsoleDisplay;
            do {
                display := ConsoleDisplay{pumpStatus=pumpStatus, vitals=vitals, fluoroImage=fluoroImage};
                displayPort.display.send(display);
            }
        }
        
        action def IssuePumpCommand {
            in targetSpeed : RotationalSpeed;
            in mode : String;
            out command : PumpCommand;
            do {
                command := PumpCommand{targetSpeed=targetSpeed, mode=mode};
                pumpControlPort.command.send(command);
            }
        }
    }
    
    part def InterventionalToolSet {
        part guideCatheter : GuideCatheter;
        part guideWire : GuideWire;
        part balloonCatheter : BalloonCatheter;
        part stent : CoronaryStent;
        
        connection guideWireThroughCatheter {
            source guideWire.proximalEnd;
            target guideCatheter.proximalPort;
        }
        connection balloonOverWire {
            source balloonCatheter.proximalPort;
            target guideWire.proximalEnd;
        }
        connection stentOnBalloon {
            source stent;
            target balloonCatheter.balloon;
        }
    }
    
    // ===== Top-level System =====
    part def ProtectedPCISystem {
        requirement ref hemodynamicReq : HemodynamicStabilityRequirement;
        requirement ref flowReq : FlowSupportRequirement;
        requirement ref monitorReq : MonitoringRequirement;
        requirement ref visReq : VisualizationRequirement;
        requirement ref stentReq : StentDeploymentRequirement;
        
        part patient : Patient;
        part mcsPump : MCSPump;
        part tools : InterventionalToolSet;
        part fluoro : FluoroscopySystem;
        part monitor : HemodynamicMonitor;
        part console : ControlConsole;
        
        // Connections: MCS pump to patient circulation
        connection mcsInletToVentricle : BloodFlowPort connect mcsPump.inletPort to patient.leftVentricle.ventriclePort;
        connection mcsOutletToAorta : BloodFlowPort connect mcsPump.outletPort to patient.aorta.aortaPort;
        
        // Connections: Guide catheter from femoral access to coronary artery
        connection catheterAccess : BloodFlowPort connect tools.guideCatheter.proximalPort to patient.femoralArtery.accessPort;
        connection catheterToCoronary : BloodFlowPort connect tools.guideCatheter.distalPort to patient.coronaryArtery.proximalPort;
        
        // Connections: Contrast injection
        connection contrastDelivery : ContrastPort connect tools.guideCatheter.contrastPort to fluoro.imagingPort;
        
        // Connections: Control console to pump
        connection consoleToPump : ControlPort connect console.pumpControlPort to mcsPump.controlPort;
        
        // Connections: Monitor to console
        connection monitorToConsole : MonitoringPort connect monitor.monitoringPort to console.monitorInputPort;
        
        // Connections: Fluoroscopy to console
        connection fluoroToConsole : ImagingPort connect fluoro.imagingPort to console.fluoroInputPort;
        
        // Connections: Monitor to patient (vital signs sensing)
        connection patientToMonitor : MonitoringPort connect patient to monitor.monitoringPort;
        
        // System-level behavior
        action def PerformProtectedPCI {
            in patient : Patient;
            in pump : MCSPump;
            in tools : InterventionalToolSet;
            in fluoro : FluoroscopySystem;
            in monitor : HemodynamicMonitor;
            in console : ControlConsole;
            
            action stabilizePatient {
                do { console.IssuePumpCommand(targetSpeed=0.0, mode="prime"); };
                then do { console.IssuePumpCommand(targetSpeed=30000, mode="activate"); };
            }
            action visualizeVessels {
                do { fluoro.AcquireImage(); };
            }
            action navigateGuideWire {
                do { fluoro.AcquireImage(); };
            }
            action crossLesion {
                do { fluoro.AcquireImage(); };
            }
            action preDilate {
                do { tools.balloonCatheter.InflateBalloon(targetPressure=10.0); };
                then do { tools.balloonCatheter.DeflateBalloon(); };
            }
            action deployStent {
                do { tools.stent.Deploy(deploymentPressure=16.0); };
            }
            action postDilate {
                do { tools.balloonCatheter.InflateBalloon(targetPressure=14.0); };
                then do { tools.balloonCatheter.DeflateBalloon(); };
            }
            action weanPump {
                do { console.IssuePumpCommand(targetSpeed=15000, mode="wean"); };
                then do { console.IssuePumpCommand(targetSpeed=0.0, mode="stop"); };
            }
            
            // Continuous monitoring throughout
            parallel {
                action continuousMonitoring {
                    do { monitor.MonitorVitals(hr=patient.heartRate, sbp=120.0, dbp=80.0, spo2=98.0); };
                }
                action continuousImaging {
                    do { fluoro.AcquireImage(); };
                }
            }
            
            succeed if { patient.coronaryArtery.blockageSeverity < 0.3 and patient.meanArterialPressure >= 65.0; }
            fail if { patient.meanArterialPressure < 50.0; }
        }
        
        exhibit PerformProtectedPCI;
    }
}
