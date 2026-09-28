using System.Collections.Generic;
using UnityEngine;

public class SmartFracture : MonoBehaviour
{
	public float breakRadius = 0.2f;

	public float breakForce = 100f;

	private List<SubFracture> cells;

	private void Start()
	{
		InitSubFractures();
	}

	private void InitSubFractures()
	{
		cells = new List<SubFracture>();
		cells.AddRange(transform.GetComponentsInChildren<SubFracture>());
		foreach (SubFracture cell in cells)
		{
			BoxCollider boxCollider = cell.gameObject.AddComponent<BoxCollider>();
			Collider[] array = Physics.OverlapBox(cell.transform.position, boxCollider.size / 2f, cell.transform.rotation);
			for (int i = 0; i < array.Length; i++)
			{
				if ((bool)array[i].GetComponent<SubFracture>() && array[i].transform.root == cell.transform.root && array[i].gameObject != cell.gameObject)
				{
					cell.connections.Add(array[i].GetComponent<SubFracture>());
					array[i].GetComponent<SubFracture>().connections.Add(cell);
					Debug.Log(cell.name + "_" + array[i].name);
				}
			}
			Object.Destroy(boxCollider);
		}
	}

	public void Fracture(Vector3 point, Vector3 force)
	{
		foreach (SubFracture cell in cells)
		{
			if (Vector3.Distance(cell.transform.position, point) < breakRadius)
			{
				cell.connections = new List<SubFracture>();
				cell.grounded = false;
				cell.GetComponent<Rigidbody>().isKinematic = false;
				cell.GetComponent<Rigidbody>().AddForceAtPosition(force, point, ForceMode.Force);
			}
		}
	}
}
