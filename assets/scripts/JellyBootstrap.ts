// Jelly Cube 3D — One-Component Scene Bootstrapper
// Attach this to the root Canvas node in Main.scene (or any empty scene)
// to auto-wire Camera, DirectionalLight, JellyCameraRig, JellyCubeView,
// JellyGameController, and JellyHUD.

import {
    _decorator,
    Camera,
    Color,
    Component,
    DirectionalLight,
    EffectAsset,
    Node,
    Vec3,
} from 'cc';
import { JellyGameController } from './ui/JellyGameController';
import { JellyHUD } from './ui/JellyHUD';
import { JellyCameraRig } from './view/JellyCameraRig';
import { JellyCubeView } from './view/JellyCubeView';

const { ccclass, property } = _decorator;

@ccclass('JellyBootstrap')
export class JellyBootstrap extends Component {
    @property(EffectAsset)
    jellyEffect: EffectAsset | null = null;

    onLoad(): void {
        const scene = this.node.scene;

        // 1. 3D Main Camera + Rig
        let camNode = scene?.getChildByName('JellyMainCamera');
        let cam: Camera;
        let rig: JellyCameraRig;
        if (!camNode) {
            camNode = new Node('JellyMainCamera');
            camNode.parent = scene ?? this.node.parent;
            cam = camNode.addComponent(Camera);
            cam.projection = Camera.ProjectionType.PERSPECTIVE;
            cam.fov = 42;
            cam.near = 0.5;
            cam.far = 100;
            cam.clearFlags = Camera.ClearFlag.SOLID_COLOR;
            cam.clearColor = new Color(255, 246, 249, 255);
            rig = camNode.addComponent(JellyCameraRig);
            rig.camera = cam;
        } else {
            cam = camNode.getComponent(Camera)!;
            rig = camNode.getComponent(JellyCameraRig) ?? camNode.addComponent(JellyCameraRig);
        }

        // 2. Studio Directional Light
        if (scene && !scene.getChildByName('JellyStudioLight')) {
            const lightNode = new Node('JellyStudioLight');
            lightNode.parent = scene;
            lightNode.setRotationFromEuler(-48, 32, 0);
            const light = lightNode.addComponent(DirectionalLight);
            light.illuminance = 65000;
        }

        // 3. 3D Jelly Cube Root — wire while inactive: addComponent runs
        // onLoad immediately, so jellyEffect/camera must be set before that.
        const cubeRoot = new Node('JellyCubeRoot');
        cubeRoot.parent = scene ?? this.node.parent;
        cubeRoot.active = false;
        cubeRoot.setPosition(Vec3.ZERO);
        const cubeView = cubeRoot.addComponent(JellyCubeView);
        cubeView.jellyEffect = this.jellyEffect;
        cubeView.camera = cam;
        cubeRoot.active = true;

        // 4. Game Controller
        const ctrl = this.node.addComponent(JellyGameController);
        ctrl.cubeView = cubeView;
        ctrl.cameraRig = rig;
        ctrl.camera = cam;

        // 5. HUD
        const hud = this.node.addComponent(JellyHUD);
        hud.controller = ctrl;
    }
}
