package 'Free Electron Laser System' {
    import ScalarValues::*;
    import ISQ::*;
    
    item def ElectronBunch {
        attribute energy : EnergyValue;
        attribute charge : ElectricChargeValue;
        attribute bunchLength : LengthValue;
    }
    
    item def PhotonBeam {
        attribute wavelength : LengthValue;
        attribute intensity : Real;
        attribute pulseEnergy : EnergyValue;
    }
    
    item def MagneticField {
        attribute strength : MagneticFluxDensityValue;
        attribute period : LengthValue;
    }
    
    attribute def BeamSpecification {
        attribute targetWavelength : LengthValue;
        attribute targetEnergy : EnergyValue;
        attribute targetFieldStrength : MagneticFluxDensityValue;
    }
    
    attribute def PowerOn;
    attribute def InitComplete;
    attribute def BeamReady;
    attribute def ShutdownCmd;
    
    port def ElectronFlowPort {
        in electronBunch : ElectronBunch;
    }
    
    port def PhotonFlowPort {
        in photonBeam : PhotonBeam;
    }
    
    port def ControlPort {
        in command : BeamSpecification;
    }
    
    port def FieldControlPort {
        in fieldSetting : MagneticField;
    }
    
    action def EmitElectrons {
        out electronBunch : ElectronBunch;
    }
    
    action def AccelerateElectrons {
        in electronBunch : ElectronBunch;
        in targetEnergy : EnergyValue;
        out acceleratedBunch : ElectronBunch;
    }
    
    action def CompressBunch {
        in electronBunch : ElectronBunch;
        out compressedBunch : ElectronBunch;
    }
    
    action def GeneratePhotons {
        in electronBunch : ElectronBunch;
        in fieldSetting : MagneticField;
        out photonBeam : PhotonBeam;
        out spentBunch : ElectronBunch;
    }
    
    action def AmplifyPhotons {
        in initialPhotons : PhotonBeam;
        in electronBunch : ElectronBunch;
        out amplifiedPhotons : PhotonBeam;
        out exitedBunch : ElectronBunch;
    }
    
    action def TransportPhotons {
        in photonBeam : PhotonBeam;
        out deliveredPhotons : PhotonBeam;
    }
    
    part def ElectronGun {
        port electronOut : ~ElectronFlowPort;
        action emit : EmitElectrons {
            out electronBunch = electronOut.electronBunch;
        }
    }
    
    part def Linac {
        port electronIn : ElectronFlowPort;
        port electronOut : ~ElectronFlowPort;
        port controlIn : ControlPort;
        action accelerate : AccelerateElectrons {
            in electronBunch = electronIn.electronBunch;
            in targetEnergy = controlIn.command.targetEnergy;
            out acceleratedBunch = electronOut.electronBunch;
        }
    }
    
    part def BunchCompressor {
        port electronIn : ElectronFlowPort;
        port electronOut : ~ElectronFlowPort;
        action compress : CompressBunch {
            in electronBunch = electronIn.electronBunch;
            out compressedBunch = electronOut.electronBunch;
        }
    }
    
    part def MagneticFieldController {
        port controlIn : ControlPort;
        port fieldOut : ~FieldControlPort;
        action adjustField {
            in command = controlIn.command;
            out fieldSetting = fieldOut.fieldSetting;
        }
    }
    
    part def Undulator {
        port electronIn : ElectronFlowPort;
        port fieldIn : FieldControlPort;
        port photonOut : ~PhotonFlowPort;
        port electronOut : ~ElectronFlowPort;
        action generate : GeneratePhotons {
            in electronBunch = electronIn.electronBunch;
            in fieldSetting = fieldIn.fieldSetting;
            out photonBeam = photonOut.photonBeam;
            out spentBunch = electronOut.electronBunch;
        }
    }
    
    part def OpticalCavity {
        port electronIn : ElectronFlowPort;
        port photonIn : PhotonFlowPort;
        port photonOut : ~PhotonFlowPort;
        port electronOut : ~ElectronFlowPort;
        action amplify : AmplifyPhotons {
            in initialPhotons = photonIn.photonBeam;
            in electronBunch = electronIn.electronBunch;
            out amplifiedPhotons = photonOut.photonBeam;
            out exitedBunch = electronOut.electronBunch;
        }
    }
    
    part def BeamlineOptics {
        port photonIn : PhotonFlowPort;
        port photonOut : ~PhotonFlowPort;
        action transport : TransportPhotons {
            in photonBeam = photonIn.photonBeam;
            out deliveredPhotons = photonOut.photonBeam;
        }
    }
    
    part def BeamDump {
        port electronIn : ElectronFlowPort;
        action absorb {
            in electronBunch = electronIn.electronBunch;
        }
    }
    
    part def ExperimentalStation {
        port photonIn : PhotonFlowPort;
        action receive {
            in photonBeam = photonIn.photonBeam;
        }
    }
    
    part def DiagnosticSystem {
        port electronMonitor : ElectronFlowPort;
        port photonMonitor : PhotonFlowPort;
        attribute beamQuality : Real;
        action monitor {
            in electronBunch = electronMonitor.electronBunch;
            in photonBeam = photonMonitor.photonBeam;
        }
    }
    
    part def TuningController {
        port cmdIn : ControlPort;
        port linacCmdOut : ~ControlPort;
        port magnetCmdOut : ~ControlPort;
        action tune {
            in command = cmdIn.command;
            out linacCommand = linacCmdOut.command;
            out magnetCommand = magnetCmdOut.command;
        }
    }
    
    part def FreeElectronLaser {
        part gun : ElectronGun;
        part linac : Linac;
        part compressor : BunchCompressor;
        part undulator : Undulator;
        part magnetController : MagneticFieldController;
        part cavity : OpticalCavity;
        part optics : BeamlineOptics;
        part dump : BeamDump;
        part station : ExperimentalStation;
        part diagnostics : DiagnosticSystem;
        part tuner : TuningController;
        
        connect gun.electronOut to linac.electronIn;
        connect linac.electronOut to compressor.electronIn;
        connect compressor.electronOut to undulator.electronIn;
        connect tuner.linacCmdOut to linac.controlIn;
        connect tuner.magnetCmdOut to magnetController.controlIn;
        connect magnetController.fieldOut to undulator.fieldIn;
        connect undulator.photonOut to cavity.photonIn;
        connect undulator.electronOut to cavity.electronIn;
        connect cavity.photonOut to optics.photonIn;
        connect cavity.electronOut to dump.electronIn;
        connect optics.photonOut to station.photonIn;
        
        connect compressor.electronOut to diagnostics.electronMonitor;
        connect optics.photonOut to diagnostics.photonMonitor;
        
        state controlState {
            state Off;
            state Standby;
            state Initializing;
            state Operating {
                state Accelerating;
                state Lasing;
                transition first Accelerating accept BeamReady then Lasing;
            }
            state Shutdown;
            transition first Off accept PowerOn then Standby;
            transition first Standby accept PowerOn then Initializing;
            transition first Initializing accept InitComplete then Operating.Accelerating;
            transition first Operating.Lasing accept ShutdownCmd then Shutdown;
            transition first Shutdown accept PowerOn then Off;
        }
    }
    
    requirement def FELTunabilityRequirement {
        doc /* The FEL shall produce light with wavelength tunable from 0.1 nm to 1000 nm. */
    }
    
    requirement def FELDiagnosticsRequirement {
        doc /* The diagnostic system shall maintain beam stability index above 0.95 during operation. */
    }
}
