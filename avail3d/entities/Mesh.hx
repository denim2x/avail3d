/**
 * Mesh is an instance of a Geometry, augmenting it with a presence in the scene graph, a material, and an animation
 * state. It consists out of SubMeshes, which in turn correspond to SubGeometries. SubMeshes allow different parts
 * of the geometry to be assigned different materials.
 */
package avail3d.entities;

import away3d.core.base.Geometry;
import away3d.materials.MaterialBase;
import away3d.materials.utils.DefaultMaterialManager;

  
//class Mesh extends Entity implements IMaterialOwner implements IAsset {
class Mesh extends away3d.entities.Mesh {
  /**
   * Create a new Mesh object.
   *
   * @param geometry The geometry used by the mesh that provides it with its shape.
   * @param material [optional] The material with which to render the Mesh.
   */
  public function new(geometry: Geometry, material: MaterialBase = null) {
    if (geometry == null) {
      geometry = new Geometry();
    }

    if (material == null) {
      material = DefaultMaterialManager.getDefaultMaterial(this);
    }

    super(geometry, material);
  }
}
