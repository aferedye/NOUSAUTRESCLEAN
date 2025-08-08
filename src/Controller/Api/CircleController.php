<?php

namespace App\Controller\Api;

use App\Entity\Circle;
use App\Repository\CircleRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/v1/circles')]
class CircleController extends AbstractController
{
    private function serialize(Circle $c): array
    {
        return $c->toArray();
    }

    #[Route('', name: 'circle_index', methods: ['GET'])]
    public function index(Request $request, CircleRepository $repo): JsonResponse
    {
        $limit = max(1, min(100, (int)($request->query->get('limit', 50))));
        $items = $repo->findBy([], ['id' => 'DESC'], $limit);
        return $this->json([
            'items' => array_map(fn(Circle $c) => $this->serialize($c), $items),
            'count' => count($items),
        ]);
    }

    #[Route('', name: 'circle_create', methods: ['POST'])]
    public function create(
        Request $request,
        EntityManagerInterface $em,
        ValidatorInterface $validator
    ): JsonResponse {
        $data = json_decode($request->getContent(), true) ?? [];
        $name = isset($data['name']) ? (string)$data['name'] : '';
        $description = array_key_exists('description', $data) ? ( $data['description'] !== null ? (string)$data['description'] : null ) : null;

        $circle = new Circle();
        $circle->setName($name);
        $circle->setDescription($description);

        $errors = $validator->validate($circle);
        if (count($errors) > 0) {
            $errs = [];
            foreach ($errors as $e) { $errs[] = ['field' => $e->getPropertyPath(), 'message' => $e->getMessage()]; }
            return $this->json(['errors' => $errs], 422);
        }

        $em->persist($circle);
        $em->flush();

        return $this->json($this->serialize($circle), 201);
    }

    #[Route('/{id<\d+>}', name: 'circle_show', methods: ['GET'])]
    public function show(Circle $circle): JsonResponse
    {
        return $this->json($this->serialize($circle));
    }

    #[Route('/{id<\d+>}', name: 'circle_update', methods: ['PUT','PATCH'])]
    public function update(
        Circle $circle,
        Request $request,
        EntityManagerInterface $em,
        ValidatorInterface $validator
    ): JsonResponse {
        $data = json_decode($request->getContent(), true) ?? [];
        if (array_key_exists('name', $data)) {
            $circle->setName((string)$data['name']);
        }
        if (array_key_exists('description', $data)) {
            $circle->setDescription($data['description'] !== null ? (string)$data['description'] : null);
        }

        $errors = $validator->validate($circle);
        if (count($errors) > 0) {
            $errs = [];
            foreach ($errors as $e) { $errs[] = ['field' => $e->getPropertyPath(), 'message' => $e->getMessage()]; }
            return $this->json(['errors' => $errs], 422);
        }

        $em->flush();
        return $this->json($this->serialize($circle));
    }

    #[Route('/{id<\d+>}', name: 'circle_delete', methods: ['DELETE'])]
    public function delete(Circle $circle, EntityManagerInterface $em): JsonResponse
    {
        $em->remove($circle);
        $em->flush();
        return $this->json(null, 204);
    }
}