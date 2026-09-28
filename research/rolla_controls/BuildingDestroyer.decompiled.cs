using UnityEngine;

public class BuildingDestroyer : MonoBehaviour
{
	public GameObject spawnPrefab1;

	public GameObject spawnPrefab2;

	public bool destroyOnStartCollision = true;

	private void Start()
	{
		if (!destroyOnStartCollision)
		{
			return;
		}
		Collider[] array = Physics.OverlapBox(transform.position, transform.localScale / 2f);
		foreach (Collider collider in array)
		{
			if (collider.CompareTag("solidobject"))
			{
				DestroyAndSpawnObjects(collider.gameObject);
			}
		}
	}

	private void OnCollisionEnter(Collision collision)
	{
		if (collision.gameObject.CompareTag("solidobject"))
		{
			DestroyAndSpawnObjects(collision.gameObject);
		}
	}

	private void DestroyAndSpawnObjects(GameObject otherObject)
	{
		Transform parent = transform.parent;
		if (spawnPrefab1 != null)
		{
			GameObject gameObject = Object.Instantiate(spawnPrefab1, transform.position, transform.rotation);
			if (parent != null)
			{
				gameObject.transform.parent = parent;
			}
		}
		if (spawnPrefab2 != null)
		{
			GameObject gameObject2 = Object.Instantiate(spawnPrefab2, transform.position, transform.rotation);
			if (parent != null)
			{
				gameObject2.transform.parent = parent;
			}
		}
		Object.Destroy(base.gameObject);
		Object.Destroy(otherObject);
	}
}
